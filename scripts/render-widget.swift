import SwiftUI
import WidgetKit
import AppKit
@main struct Render {
    @MainActor static func main() {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass an output directory") }
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let snapshot = FanSnapshot(fans: [FanReading(id: 0, actual: 7826, minimum: 2317, maximum: 7826, target: 7826, mode: 1), FanReading(id: 1, actual: 7808, minimum: 2317, maximum: 7826, target: 7826, mode: 1)], selected: .max, expires: Date().addingTimeInterval(300), connected: true, onBattery: true)
        for small in [true, false] {
            let view = FanWidgetView(entry: FanEntry(date: Date(), snapshot: snapshot), previewFamily: small ? .systemSmall : .systemMedium).content
                .frame(width: small ? 132 : 300, height: 132)
                .padding(16).background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 28))
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view); renderer.scale = 3
            if let cg = renderer.cgImage {
                let rep = NSBitmapImageRep(cgImage: cg)
                try! rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("Widget-\(small ? "small" : "medium")-layout.png"))
            }
        }
    }
}
