import SwiftUI

struct LeverNotch: View {
    let setting: FanSetting
    let selected: Bool
    var compact = false
    var body: some View {
        VStack(spacing: compact ? 5 : 12) {
            Text(setting.label).font(.system(size: 11, weight: selected ? .bold : .medium, design: .rounded))
                .foregroundStyle(selected ? .primary : .secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
            RoundedRectangle(cornerRadius: 1).fill(.primary.opacity(selected ? 0.9 : 0.28)).frame(width: 2, height: 8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity).frame(height: compact ? 48 : 63)
        .contentShape(Rectangle())
    }
}

struct LeverView<Notch: View>: View {
    let selected: FanSetting?
    var settings: [FanSetting] = FanSetting.allCases
    var compact = false
    @ViewBuilder var notch: (FanSetting) -> Notch
    var body: some View {
        GeometryReader { geometry in
            let cell = geometry.size.width / CGFloat(settings.count)
            let handleWidth = min(cell - 3, 29)
            ZStack(alignment: .topLeading) {
                Capsule().fill(.fill)
                    .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
                    .frame(width: geometry.size.width - cell, height: 7)
                    .offset(x: cell / 2, y: compact ? 32 : 44)
                    .accessibilityHidden(true).allowsHitTesting(false)
                if let selected, let index = settings.firstIndex(of: selected) {
                    // Like a system slider, the track fills with the accent up to the handle, ending just
                    // under its edge so the fill's rounded end doesn't show through the glass.
                    if index > 0 {
                        Capsule().fill(.tint)
                            .frame(width: cell * CGFloat(index) - handleWidth / 2 + 4, height: 7)
                            .offset(x: cell / 2, y: compact ? 32 : 44)
                            .widgetAccentable()
                            .accessibilityHidden(true).allowsHitTesting(false)
                    }
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.linearGradient(colors: [.white.opacity(0.85), .white.opacity(0.30), .gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.8), lineWidth: 0.8))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(.separator, lineWidth: 0.5))
                        .overlay(HStack(spacing: 3) {
                            ForEach(0..<3) { _ in Capsule().fill(.black.opacity(0.26)).frame(width: 1, height: 9) }
                        })
                        .shadow(color: .black.opacity(0.20), radius: 3, y: 2)
                        .frame(width: handleWidth, height: 25)
                        .offset(x: cell * (CGFloat(index) + 0.5) - handleWidth / 2, y: compact ? 23 : 35)
                        .accessibilityHidden(true).allowsHitTesting(false)
                }
                HStack(spacing: 0) { ForEach(settings) { setting in notch(setting).frame(width: cell) } }
            }
        }.frame(height: compact ? 49 : 66)
    }
}

struct FanRPMView: View {
    let snapshot: FanSnapshot
    var body: some View {
        HStack(spacing: 10) {
            ForEach(snapshot.fans) { fan in
                Text("F\(fan.id + 1) \(Int(fan.actual).formatted())")
            }
            if !snapshot.fans.isEmpty { Text("RPM").foregroundStyle(.tertiary) }
        }.font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
    }
}
