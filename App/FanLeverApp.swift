import SwiftUI
#if DEBUG
import ServiceManagement
import WidgetKit
#if DEBUG
import DevFeedback
#endif



@MainActor final class FanModel: ObservableObject {
    @Published var snapshot = FanSnapshot.unavailable
    @Published var busy = false
    @Published var serviceStatus = SMAppService.Status.notRegistered
    @Published var setupError: String?
    let service = SMAppService.daemon(plistName: "space.monroe.FanLever.helper.plist")
    func refresh() async {
        guard !busy else { return }
        serviceStatus = service.status
        let result = await FanClient.request()
        guard !busy else { return }
        if result.connected { snapshot = result; setupError = nil }
        else {
            var fallback = result
            if let device = try? SMCDevice(), let fans = try? device.readings() { fallback.fans = fans; fallback.selected = fans.allSatisfy(\.isAutomatic) ? .auto : nil }
            snapshot = fallback
        }
        SnapshotStore.save(snapshot)
    }
    func select(_ setting: FanSetting) async {
        guard !busy else { return }
        busy = true
        snapshot = await FanClient.request(setting)
        SnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: FanConstants.widgetKind)
        busy = false
    }
    func enable() async {
        setupError = nil
        do { try service.register() }
        catch { setupError = error.localizedDescription }
        serviceStatus = service.status
        if serviceStatus == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        await refresh()
    }
    func disable() async {
        await select(.auto)
        guard snapshot.connected, snapshot.selected == .auto, snapshot.message == nil else {
            setupError = "Confirm automatic cooling before disabling the helper."; return
        }
        do { try await service.unregister(); serviceStatus = service.status }
        catch { setupError = error.localizedDescription }
        await refresh()
    }
}

struct FanControlView: View {
    @StateObject private var model = FanModel()
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(systemName: "fanblades.fill").font(.system(size: 28)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Fan Lever").font(.title2.weight(.semibold)).feedbackTarget("header.title", label: "App title")
                    Text("A little more breeze.").foregroundStyle(.secondary).feedbackTarget("header.subtitle", label: "App subtitle")
                }
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
            }
            VStack(alignment: .leading, spacing: 14) {
                LeverView(selected: model.snapshot.selected) { setting in
                    Button { Task { await model.select(setting) } } label: {
                        LeverNotch(setting: setting, selected: model.snapshot.selected == setting)
                    }
                    .buttonStyle(.plain).disabled(model.busy || !model.snapshot.connected)
                    .help(setting.description)
                    .accessibilityLabel(setting.description)
                    .accessibilityAddTraits(model.snapshot.selected == setting ? .isSelected : [])
                    .feedbackTarget("lever.notch.\(setting.rawValue)", label: "Fan notch")
                }
                .feedbackTarget("lever.track", label: "Fan lever")
                FanRPMView(snapshot: model.snapshot).feedbackTarget("telemetry.rpm", label: "Measured fan RPM")
                Text(model.snapshot.status).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).feedbackTarget("telemetry.status", label: "Controller status")
                if let expires = model.snapshot.expires {
                    HStack { Text("Returns to Auto in"); Text(expires, style: .timer) }.font(.caption).foregroundStyle(.secondary)
                        .feedbackTarget("telemetry.expiry", label: "Automatic cooling countdown")
                }
            }
            .padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            if !model.snapshot.connected {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enable fan control").font(.headline).feedbackTarget("setup.title", label: "Setup heading")
                    Text("macOS needs your approval for the Fan Lever helper to change fan speed. It accepts only these six settings, stays within each fan’s reported limits, and returns manual settings to Auto after 30 minutes.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        .feedbackTarget("setup.explanation", label: "Fan helper explanation")
                    HStack {
                        Button(model.serviceStatus == .requiresApproval ? "Open System Settings" : "Enable Fan Control") {
                            if model.serviceStatus == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
                            else { Task { await model.enable() } }
                        }.buttonStyle(.glassProminent).feedbackTarget("setup.enable", label: "Enable fan control")
                        Button("Check Again") { Task { await model.refresh() } }.feedbackTarget("setup.refresh", label: "Check helper status")
                    }
                }
            }
            if let error = model.setupError { Text(error).font(.callout).foregroundStyle(.red).textSelection(.enabled) }
            VStack(alignment: .leading, spacing: 8) {
                Text("Add it to your desktop").font(.headline).feedbackTarget("widget.title", label: "Widget setup heading")
                Text("Control-click the desktop → Edit Widgets → Fan Lever. Choose the small or medium lever. Its glass appearance follows your macOS widget style.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    .feedbackTarget("widget.instructions", label: "Widget setup instructions")
                Text("1 · 40%    2 · 55%    3 · 70%    4 · 85%    Max · 100%")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    .feedbackTarget("widget.speeds", label: "Notch speed mapping")
            }
            HStack {
                Text("Auto lets macOS manage cooling.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if model.snapshot.connected {
                    Button("Disable Helper") { Task { await model.disable() } }.font(.caption)
                        .feedbackTarget("setup.disable", label: "Disable fan helper")
                }
            }
        }
        .padding(28).frame(width: 460)
        .task {
            while !Task.isCancelled {
                await model.refresh()
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
            }
        }
    }
}

struct FanLeverApp: App {
    var body: some Scene {
        Window("Fan Lever", id: "main") {
            #if DEBUG
            FanControlView().feedbackOverlay(appID: "space.monroe.FanLever", screen: "control")
            #else
            FanControlView()
            #endif
        }
        .windowResizability(.contentSize)
        #if DEBUG
        .commands {
            FeedbackCommands()
        }
        #endif
    }
}

#if !DEBUG
extension View {
    func feedbackTarget(_ id: @autoclosure () -> String, label: @autoclosure () -> String) -> some View { self }
}
#endif

#endif // Development-only companion preview.
