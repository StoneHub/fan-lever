import Foundation

enum FanSetting: Int, Codable, CaseIterable, Identifiable {
    case auto = 0, one, two, three, four, max
    var id: Int { rawValue }
    var label: String { switch self { case .auto: "AUTO"; case .max: "MAX"; default: String(rawValue) } }
    var fraction: Double? { switch self { case .auto: nil; case .one: 0.40; case .two: 0.55; case .three: 0.70; case .four: 0.85; case .max: 1 } }
    var description: String { fraction.map { "\(Int($0 * 100))% fan speed" } ?? "macOS automatic cooling" }
    func target(for fan: FanReading) throws -> Double {
        guard let fraction, fan.minimum.isFinite, fan.maximum.isFinite,
              fan.minimum > 0, fan.maximum >= fan.minimum, fan.maximum <= 20000 else {
            throw FanError.message("Invalid fan limits. Automatic cooling remains available.")
        }
        return min(fan.maximum, Swift.max(fan.minimum, (fan.maximum * fraction).rounded()))
    }
}

struct FanReading: Codable, Identifiable {
    let id: Int
    let actual: Double
    let minimum: Double
    let maximum: Double
    let target: Double
    let mode: Int
    var isAutomatic: Bool { mode == 0 || mode == 3 }
}

struct FanSnapshot: Codable {
    var date = Date()
    var fans: [FanReading] = []
    var selected: FanSetting? = nil
    var expires: Date? = nil
    var message: String? = nil
    var connected = false
    static let unavailable = FanSnapshot(message: "Open Fan Lever to enable fan control.")
    static let preview = FanSnapshot(fans: [
        .init(id: 0, actual: 4300, minimum: 2300, maximum: 7800, target: 4300, mode: 0),
        .init(id: 1, actual: 4600, minimum: 2300, maximum: 7800, target: 4600, mode: 0)
    ], selected: .auto, connected: true)
    var status: String {
        if let message { return message }
        if !connected { return "Fan control needs setup" }
        return selected?.description ?? "Controlled outside Fan Lever"
    }
}

enum FanError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(value) = self { return value }; return nil }
}

enum FanConstants {
    static let service = "space.monroe.FanLever.helper"
    static let widgetKind = "FanLeverWidget"
    static let group = "N6GPP46885.group.space.monroe.FanLever"
    static let lease: TimeInterval = 30 * 60
    static let signedTeam = "anchor apple generic and certificate leaf[subject.OU] = \"N6GPP46885\""
}

@objc protocol FanServiceProtocol {
    func snapshot(reply: @escaping (Data) -> Void)
    func select(_ setting: Int, reply: @escaping (Data) -> Void)
}
