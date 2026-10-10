import Foundation

// Accessed on the helper's one serial queue. No arbitrary keys or RPMs cross IPC.
final class FanController {
    let hardware: FanHardware
    let markOwnership: () throws -> Void
    let clearOwnership: () -> Void
    let onBattery: () -> Bool
    var selected: FanSetting?
    var expires: Date?
    var lastError: String?
    var ownsFans = false
    init(hardware: FanHardware, markOwnership: @escaping () throws -> Void = {}, clearOwnership: @escaping () -> Void = {}, onBattery: @escaping () -> Bool = { false }) {
        self.hardware = hardware; self.markOwnership = markOwnership; self.clearOwnership = clearOwnership
        self.onBattery = onBattery
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
                selected = setting
                expires = now.addingTimeInterval(onBattery() ? FanConstants.batteryLease : FanConstants.lease)
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
    /// Shortens the active boost to the next timer step below the time left, wrapping from the
    /// shortest back to the longest. Steps never exceed the current power source's lease.
    func cycleAutoTimer(now: Date = Date()) -> FanSnapshot {
        guard ownsFans, let setting = selected, setting != .auto, let deadline = expires, deadline > now else { return status() }
        let lease = onBattery() ? FanConstants.batteryLease : FanConstants.lease
        let steps = FanConstants.timerSteps.filter { $0 <= lease }
        let remaining = deadline.timeIntervalSince(now)
        expires = now.addingTimeInterval(steps.first { $0 < remaining } ?? lease)
        return status()
    }
    func tick(now: Date = Date(), thermalEmergency: Bool = false) {
        guard ownsFans else { return }
        if onBattery(), let deadline = expires {
            expires = min(deadline, now.addingTimeInterval(FanConstants.batteryLease))
        }
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
                               message: lastError, connected: true, onBattery: onBattery(), canCycleTimer: true)
        } catch { return FanSnapshot(message: error.localizedDescription, connected: true) }
    }
}
