import Foundation

enum SnapshotStore {
    private static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: FanConstants.group)?.appendingPathComponent("snapshot.json")
    }
    static func read() -> FanSnapshot {
        guard let url, let data = try? Data(contentsOf: url), let snapshot = try? JSONDecoder().decode(FanSnapshot.self, from: data) else { return .unavailable }
        return snapshot
    }
    static func save(_ snapshot: FanSnapshot) {
        guard let url, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

// completion is consumed exactly once under the lock, including XPC/timeout races.
private final class ReplyGate: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: ((FanSnapshot) -> Void)?
    init(_ completion: @escaping (FanSnapshot) -> Void) { self.completion = completion }
    func finish(_ value: FanSnapshot) {
        lock.lock(); let callback = completion; completion = nil; lock.unlock()
        callback?(value)
    }
}

enum FanClient {
    static func request(_ setting: FanSetting? = nil) async -> FanSnapshot {
        await withCheckedContinuation { continuation in
            let connection = NSXPCConnection(machServiceName: FanConstants.service, options: .privileged)
            connection.remoteObjectInterface = NSXPCInterface(with: FanServiceProtocol.self)
            connection.setCodeSigningRequirement(FanConstants.signedTeam + " and identifier \"space.monroe.FanLever.helper\"")
            let gate = ReplyGate { snapshot in
                connection.invalidate()
                continuation.resume(returning: snapshot)
            }
            let failed = { gate.finish(FanSnapshot(message: "Open Fan Lever to enable or repair fan control.")) }
            connection.interruptionHandler = failed
            connection.invalidationHandler = failed
            connection.resume()
            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in failed() }) as? FanServiceProtocol else { failed(); return }
            let reply: (Data) -> Void = { data in
                guard let snapshot = try? JSONDecoder().decode(FanSnapshot.self, from: data) else { failed(); return }
                gate.finish(snapshot)
            }
            if let setting { proxy.select(setting.rawValue, reply: reply) } else { proxy.snapshot(reply: reply) }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                gate.finish(FanSnapshot(message: "Fan controller timed out. Open Fan Lever to check the actual state."))
            }
        }
    }
}
