// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FanLeverCore", platforms: [.macOS(.v14)], targets: [
    .target(name: "CSMC", path: "SMC", exclude: ["SMCDevice.swift"], sources: ["FanSMC.c"], publicHeadersPath: ".", linkerSettings: [.linkedFramework("IOKit")]),
    .target(name: "FanCore", dependencies: ["CSMC"], path: ".", exclude: ["App", "Widget", "Vendor", "Config", "Tests", "scripts", "SMC/FanSMC.c", "SMC/FanSMC.h", "Shared/FanClient.swift", "Shared/LeverView.swift", "Shared/SetFanIntent.swift", "Helper/main.swift", "project.yml"], sources: ["Shared/Models.swift", "SMC/SMCDevice.swift", "Helper/FanController.swift"]),
    .testTarget(name: "FanCoreTests", dependencies: ["FanCore"], path: "Tests")
])
