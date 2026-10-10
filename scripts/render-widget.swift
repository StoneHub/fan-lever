import SwiftUI
import WidgetKit
import AppKit
@main struct Render {
    @MainActor static func main() {
        // Arguments after the directory are user-defaults overrides, such as `-AppleAccentColor 5` to preview an accent.
        guard CommandLine.arguments.count >= 2 else { fatalError("Pass an output directory") }
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let snapshot = FanSnapshot(fans: [FanReading(id: 0, actual: 7826, minimum: 2317, maximum: 7826, target: 7826, mode: 1), FanReading(id: 1, actual: 7808, minimum: 2317, maximum: 7826, target: 7826, mode: 1)], selected: .max, expires: Date().addingTimeInterval(300), connected: true, onBattery: true, canCycleTimer: true)
        // The solid backdrop stands in for the system glass platter, which only the desktop draws.
        for scheme in [ColorScheme.dark, .light] {
            for small in [true, false] {
                let view = FanWidgetView(entry: FanEntry(date: Date(), snapshot: snapshot), previewFamily: small ? .systemSmall : .systemMedium).content
                    .tint(WidgetChrome.accent)
                    .frame(width: small ? 132 : 300, height: 132)
                    .padding(16).background(Color(white: scheme == .dark ? 0.12 : 0.95), in: RoundedRectangle(cornerRadius: 28))
                    .environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: view); renderer.scale = 3
                if let cg = renderer.cgImage {
                    let rep = NSBitmapImageRep(cgImage: cg)
                    try! rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("Widget-\(small ? "small" : "medium")-\(scheme == .dark ? "dark" : "light").png"))
                }
            }
        }
    }
}
