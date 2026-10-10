import Foundation
import Darwin

let markerPath = "/var/run/space.monroe.FanLever.owned"
func markOwnership() throws {
    let fd = open(markerPath, O_WRONLY | O_CREAT | O_NOFOLLOW, S_IRUSR | S_IWUSR)
    guard fd >= 0 else { throw FanError.message("Cannot record recovery state.") }
    defer { close(fd) }
    var st = stat()
    guard fstat(fd, &st) == 0, st.st_uid == 0, st.st_nlink == 1, (st.st_mode & S_IFMT) == S_IFREG else {
        throw FanError.message("Recovery state has unexpected ownership.")
    }
    guard fsync(fd) == 0 else { throw FanError.message("Cannot save recovery state.") }
}

final class Service: NSObject, FanServiceProtocol, NSXPCListenerDelegate {
    let queue = DispatchQueue(label: "space.monroe.FanLever.hardware")
    let controller: FanController
    init(controller: FanController) { self.controller = controller }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier != 0 else { return false }
        connection.exportedInterface = NSXPCInterface(with: FanServiceProtocol.self)
        connection.exportedObject = self
        connection.resume(); return true
    }
    func snapshot(reply: @escaping (Data) -> Void) {
        queue.async { reply(self.encode(self.controller.status())) }
    }
    func select(_ setting: Int, reply: @escaping (Data) -> Void) {
        queue.async { reply(self.encode(self.controller.select(setting))) }
    }
    private func encode(_ snapshot: FanSnapshot) -> Data { (try? JSONEncoder().encode(snapshot)) ?? Data() }
}

guard geteuid() == 0 else { fputs("Fan Lever helper must be launched by macOS.\n", stderr); exit(1) }
do {
    let controller = FanController(hardware: try SMCDevice(), markOwnership: markOwnership,
                                   clearOwnership: { unlink(markerPath) })
    // A crash/relaunch returns our previous override to Auto, never a stranger's setting.
    if FileManager.default.fileExists(atPath: markerPath) {
        controller.ownsFans = true
        do { try controller.restoreAutomatic() }
        catch { controller.lastError = "Recovering Auto: \(error.localizedDescription)" }
    }
    let service = Service(controller: controller)
    let listener = NSXPCListener(machServiceName: FanConstants.service)
    listener.setConnectionCodeSigningRequirement(FanConstants.signedTeam +
        " and (identifier \"space.monroe.FanLever\" or identifier \"space.monroe.FanLever.widget\")")
    listener.delegate = service
    listener.resume()
    let timer = DispatchSource.makeTimerSource(queue: service.queue)
    timer.schedule(deadline: .now() + 2, repeating: 2, leeway: .milliseconds(300))
    timer.setEventHandler {
        controller.tick(thermalEmergency: ProcessInfo.processInfo.thermalState == .serious || ProcessInfo.processInfo.thermalState == .critical)
    }
    timer.resume()
    signal(SIGTERM, SIG_IGN); signal(SIGINT, SIG_IGN)
    let terminate = DispatchSource.makeSignalSource(signal: SIGTERM, queue: service.queue)
    let interrupt = DispatchSource.makeSignalSource(signal: SIGINT, queue: service.queue)
    let stop = { if controller.ownsFans { try? controller.restoreAutomatic() }; exit(0) }
    terminate.setEventHandler(handler: stop); interrupt.setEventHandler(handler: stop)
    terminate.resume(); interrupt.resume()
    dispatchMain()
} catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
