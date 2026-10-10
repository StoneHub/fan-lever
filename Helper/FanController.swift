import Foundation

// Accessed on the helper's one serial queue. No arbitrary keys or RPMs cross IPC.
final class FanController {
    let hardware: FanHardware
    let markOwnership: () throws -> Void
    let clearOwnership: () -> Void
    var selected: FanSetting?
    var expires: Date?
    var lastError: String?
    var ownsFans = false
    init(hardware: FanHardware, markOwnership: @escaping () throws -> Void = {}, clearOwnership: @escaping () -> Void = {}) {
        self.hardware = hardware; self.markOwnership = markOwnership; self.clearOwnership = clearOwnership
    }
    func restoreAutomatic() throws {
        let ids = try hardware.fanIDs()
        var failures: [String] = []
        for id in ids { do { try hardware.automatic(id) } catch { failures.append(error.localizedDescription) } }
        selected = nil; expires = nil
        guard failures.isEmpty else { throw FanError.message(failures.joined(separator: " ")) }
        ownsFans = false; clearOwnership(); selected = .auto
    }
    func select(_ raw: Int, now: Date = Date()) -> FanSnapshot {
        guard let setting = FanSetting(rawValue: raw) else {
            var result = status(); result.message = "Invalid fan setting."; return result
        }
        do {
            if setting == .auto { try restoreAutomatic() }
            else {
                let fans = try hardware.readings()
                let targets = try fans.map { try setting.target(for: $0) }
                // Record ownership before the first write, including partial failures.
                try markOwnership(); ownsFans = true
                for (fan, target) in zip(fans, targets) { try hardware.manual(fan, target: target) }
                selected = setting; expires = now.addingTimeInterval(FanConstants.lease)
            }
            lastError = nil
        } catch {
            let original = error.localizedDescription
            if ownsFans {
                do { try restoreAutomatic(); lastError = "\(original) Returned to Auto." }
                catch { lastError = "\(original) Auto recovery failed: \(error.localizedDescription)" }
            } else { lastError = original }
        }
        return status()
    }
    func tick(now: Date = Date(), thermalEmergency: Bool = false) {
        guard ownsFans else { return }
        if expires == nil || now >= expires! || thermalEmergency {
            do {
                try restoreAutomatic()
                lastError = thermalEmergency ? "Returned to Auto because of thermal pressure." : nil
            } catch { lastError = "Auto recovery needs attention: \(error.localizedDescription)" }
        }
    }
    func status() -> FanSnapshot {
        do {
            let fans = try hardware.readings()
            var actualSelection: FanSetting?
            if fans.allSatisfy(\.isAutomatic) { actualSelection = .auto }
            else if let selected, selected != .auto,
                    fans.allSatisfy({ fan in fan.mode == 1 && abs(fan.target - ((try? selected.target(for: fan)) ?? -99999)) <= 8 }) {
                actualSelection = selected
            }
            return FanSnapshot(fans: fans, selected: actualSelection, expires: actualSelection == .auto ? nil : expires,
                               message: lastError, connected: true)
        } catch { return FanSnapshot(message: error.localizedDescription, connected: true) }
    }
}
