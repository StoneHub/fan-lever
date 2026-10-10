import Foundation
#if canImport(CSMC)
import CSMC
#endif

protocol FanHardware: AnyObject {
    func fanIDs() throws -> [Int]
    func readings() throws -> [FanReading]
    func manual(_ fan: FanReading, target: Double) throws
    func automatic(_ id: Int) throws
}

final class SMCDevice: FanHardware {
    private var connection: UInt32 = 0
    init() throws {
        let result = fl_open(&connection)
        guard result == 0 else { throw FanError.message("Cannot open AppleSMC (\(result)).") }
    }
    deinit { fl_close(connection) }
    private func read(_ key: String) throws -> Double {
        var value = 0.0
        let result = fl_read(connection, key, &value)
        guard result == 0 else { throw FanError.message("Cannot read \(key) (\(result)).") }
        return value
    }
    private func write(_ key: String, _ value: Double) throws {
        let result = fl_write(connection, key, value)
        guard result == 0 else { throw FanError.message("Fan controller rejected \(key) (\(result)).") }
    }
    private func modeKey(_ id: Int) throws -> String {
        guard (0..<10).contains(id) else { throw FanError.message("Invalid fan index.") }
        if (try? read("F\(id)md")) != nil { return "F\(id)md" }
        _ = try read("F\(id)Md")
        return "F\(id)Md"
    }
    func fanIDs() throws -> [Int] {
        let count = try read("FNum")
        guard count >= 1, count <= 10, count.rounded() == count else { throw FanError.message("No supported fans found.") }
        return Array(0..<Int(count))
    }
    func readings() throws -> [FanReading] {
        return try fanIDs().map { id in
            FanReading(id: id, actual: try read("F\(id)Ac"), minimum: try read("F\(id)Mn"),
                       maximum: try read("F\(id)Mx"), target: try read("F\(id)Tg"), mode: Int(try read(modeKey(id))))
        }
    }
    func manual(_ fan: FanReading, target: Double) throws {
        guard target >= fan.minimum, target <= fan.maximum, target.isFinite else { throw FanError.message("Requested speed is outside the fan limits.") }
        let key = try modeKey(fan.id)
        // Direct mode only. Never write diagnostic/unlock keys or disable the thermal manager.
        try write(key, 1)
        try confirm(key, expected: 1, tolerance: 0)
        try write("F\(fan.id)Tg", target)
        try confirm("F\(fan.id)Tg", expected: target, tolerance: 8)
    }
    private func confirm(_ key: String, expected: Double, tolerance: Double) throws {
        var observed = try read(key)
        for _ in 0..<15 {
            if abs(observed - expected) <= tolerance { return }
            Thread.sleep(forTimeInterval: 0.05)
            observed = try read(key)
        }
        throw FanError.message("Controller read-back for \(key) was \(Int(observed)); requested \(Int(expected)).")
    }
    func automatic(_ id: Int) throws {
        let key = try modeKey(id)
        try write(key, 0)
        let mode = try read(key)
        guard mode == 0 || mode == 3 else { throw FanError.message("Automatic cooling could not be confirmed for fan \(id + 1).") }
    }
}
