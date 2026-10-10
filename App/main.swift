import Foundation
import SwiftUI

func printSnapshot(_ snapshot: FanSnapshot) {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
    if let data = try? encoder.encode(snapshot), let text = String(data: data, encoding: .utf8) { print(text) }
}
let args = CommandLine.arguments
if args.contains("--probe") {
    do { printSnapshot(FanSnapshot(fans: try SMCDevice().readings())); exit(0) }
    catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
} else if args.contains("--status") || args.contains("--select") {
    var selection: FanSetting?
    if let index = args.firstIndex(of: "--select") {
        guard args.indices.contains(index + 1), let raw = Int(args[index + 1]), let setting = FanSetting(rawValue: raw) else { exit(2) }
        selection = setting
    }
    let requested = selection
    Task {
        let result = await FanClient.request(requested)
        printSnapshot(result)
        exit(result.connected && result.message == nil ? 0 : 1)
    }
    dispatchMain()
} else { FanLeverApp.main() }
