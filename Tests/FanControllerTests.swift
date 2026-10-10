import XCTest
@testable import FanCore

final class FakeHardware: FanHardware {
    var fans = [0, 1].map { FanReading(id: $0, actual: 3000, minimum: 2300, maximum: 7800, target: 3000, mode: 0) }
    var failManual: Int?
    var failAuto: Int?
    var failReadings = false
    var autoAttempts: [Int] = []
    func fanIDs() throws -> [Int] { fans.map(\.id) }
    func readings() throws -> [FanReading] {
        if failReadings { throw FanError.message("RPM sensor unavailable") }
        return fans
    }
    func manual(_ fan: FanReading, target: Double) throws {
        if failManual == fan.id { throw FanError.message("write failed") }
        fans[fan.id] = FanReading(id: fan.id, actual: fan.actual, minimum: fan.minimum, maximum: fan.maximum, target: target, mode: 1)
    }
    func automatic(_ id: Int) throws {
        autoAttempts.append(id)
        if failAuto == id { throw FanError.message("auto failed") }
        let old = fans[id]
        fans[id] = FanReading(id: id, actual: old.actual, minimum: old.minimum, maximum: old.maximum, target: old.target, mode: 0)
    }
}

final class FanControllerTests: XCTestCase {
    func testAutoRecoveryDoesNotDependOnRPMSensorReads() {
        let hw = FakeHardware(); let controller = FanController(hardware: hw)
        _ = controller.select(5)
        hw.failReadings = true
        controller.tick(thermalEmergency: true)
        XCTAssertTrue(hw.fans.allSatisfy(\.isAutomatic))
        XCTAssertFalse(controller.ownsFans)
    }
    func testMaxUsesEachFansOwnLimit() {
        let hw = FakeHardware()
        hw.fans[1] = FanReading(id: 1, actual: 2000, minimum: 1500, maximum: 6400, target: 2000, mode: 0)
        let controller = FanController(hardware: hw)
        let result = controller.select(5)
        XCTAssertEqual(result.fans.map(\.target), [7800, 6400])
        XCTAssertEqual(result.selected, .max)
    }
    func testLowerNotchClampsToMinimum() throws {
        let fan = FanReading(id: 0, actual: 5000, minimum: 5000, maximum: 6000, target: 5000, mode: 0)
        XCTAssertEqual(try FanSetting.one.target(for: fan), 5000)
    }
    func testInvalidLimitsFailBeforeAnyWrite() {
        let hw = FakeHardware()
        hw.fans[1] = FanReading(id: 1, actual: 2000, minimum: 4000, maximum: 3000, target: 2000, mode: 0)
        let result = FanController(hardware: hw).select(2)
        XCTAssertNotNil(result.message)
        XCTAssertTrue(hw.fans.allSatisfy(\.isAutomatic))
    }
    func testPartialFailureRestoresBothFans() {
        let hw = FakeHardware(); hw.failManual = 1
        let controller = FanController(hardware: hw)
        let result = controller.select(5)
        XCTAssertEqual(hw.autoAttempts, [0, 1]); XCTAssertTrue(result.fans.allSatisfy(\.isAutomatic))
        XCTAssertEqual(result.selected, .auto); XCTAssertNotNil(result.message)
        XCTAssertFalse(controller.ownsFans)
    }
    func testRollbackFailureRetainsOwnershipForWatchdog() {
        let hw = FakeHardware(); hw.failManual = 1; hw.failAuto = 0
        let controller = FanController(hardware: hw)
        XCTAssertNotNil(controller.select(5).message)
        XCTAssertTrue(controller.ownsFans); XCTAssertEqual(hw.autoAttempts, [0, 1])
        hw.failAuto = nil; controller.tick()
        XCTAssertFalse(controller.ownsFans); XCTAssertTrue(hw.fans.allSatisfy(\.isAutomatic))
    }
    func testLeaseExpiryAndThermalPressureReturnAuto() {
        for thermal in [false, true] {
            let hw = FakeHardware(); let controller = FanController(hardware: hw)
            let start = Date(timeIntervalSince1970: 100)
            _ = controller.select(4, now: start)
            controller.tick(now: start.addingTimeInterval(thermal ? 1 : 1801), thermalEmergency: thermal)
            XCTAssertTrue(hw.fans.allSatisfy(\.isAutomatic))
            XCTAssertNil(controller.expires)
        }
    }
    func testInvalidNotchDoesNotChangeExistingSetting() {
        let hw = FakeHardware(); let controller = FanController(hardware: hw)
        _ = controller.select(3)
        let result = controller.select(99)
        XCTAssertEqual(result.selected, .three); XCTAssertNotNil(result.message)
    }
    func testOwnershipMustBeRecordedBeforeChangingFans() {
        let hw = FakeHardware()
        let controller = FanController(hardware: hw, markOwnership: { throw FanError.message("disk error") })
        XCTAssertNotNil(controller.select(5).message)
        XCTAssertTrue(hw.fans.allSatisfy(\.isAutomatic))
    }
    func testExternalModeChangeIsNotShownAsSelectedNotch() {
        let hw = FakeHardware(); let controller = FanController(hardware: hw)
        _ = controller.select(2)
        hw.fans[0] = FanReading(id: 0, actual: 3000, minimum: 2300, maximum: 7800, target: 7000, mode: 1)
        XCTAssertNil(controller.status().selected)
    }
}
