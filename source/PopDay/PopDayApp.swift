import SwiftUI
import AppKit
import Combine

@main struct PopDayApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var gadget = GadgetController()
    var body: some Scene {
        Window("POPZILLA", id: "main") { ContentView().environmentObject(model).environmentObject(gadget) }
            .defaultSize(width: 430, height: 690)
        MenuBarExtra("POPZILLA", systemImage: "sparkles") {
            MenuPanel().environmentObject(model).environmentObject(gadget)
        }.menuBarExtraStyle(.window)
    }
}
struct MenuPanel: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var gadget: GadgetController
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("POPZILLA").font(.headline)
            ForEach(model.state.tasks.filter { !$0.later && !$0.done }.prefix(3)) { task in
                Button(task.title) { model.toggle(task.id) }
            }
            Button(gadget.visible ? "隐藏桌面哥斯拉" : "显示桌面哥斯拉") { gadget.toggle() }
            Button("打开 App / 语音输入") { openWindow(id: "main"); NSApplication.shared.activate(ignoringOtherApps: true) }
            Button("退出") { NSApplication.shared.terminate(nil) }
        }.padding(20).frame(width: 290).onAppear { model.refresh() }
    }
}


/// One live desktop panel and one control app share the same model.
@MainActor final class GadgetController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var visible = false
    @Published var showOnLaunch = UserDefaults.standard.object(forKey: "gadgetShowOnLaunch") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showOnLaunch, forKey: "gadgetShowOnLaunch") }
    }
    private var panel: NSPanel?
    private weak var model: AppModel?
    private var configured = false
    private var openControl: (() -> Void)?
    func openApp() {
        openControl?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.windows.first { $0.title == "POPZILLA" }?.makeKeyAndOrderFront(nil)
        }
    }
    func configure(model: AppModel, openApp: @escaping () -> Void) {
        openControl = openApp
        guard !configured else { return }
        configured = true; self.model = model
        if showOnLaunch { show() }
    }
    func toggle() { visible ? hide() : show() }
    func show() {
        guard let model else { return }
        if panel == nil {
            let window = DesktopGadgetPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 440), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.title = "POPZILLA · 桌面哥斯拉"
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.acceptsMouseMovedEvents = true
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            window.isFloatingPanel = false
            window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
            window.isExcludedFromWindowsMenu = true
            window.tabbingMode = .disallowed
            window.becomesKeyOnlyIfNeeded = true
            window.animationBehavior = .none
            window.minSize = NSSize(width: 300, height: 360)
            window.maxSize = NSSize(width: 650, height: 760)
            window.delegate = self
            window.contentView = DesktopHostingView(rootView: GadgetView().environmentObject(model).environmentObject(self))
            if !window.setFrameUsingName("PopDayDesktopGadget") {
                if let screen = NSScreen.main {
                    let area = screen.visibleFrame
                    window.setFrameOrigin(NSPoint(x: area.maxX - window.frame.width - 24, y: area.minY + 24))
                }
            }
            window.setFrameAutosaveName("PopDayDesktopGadget")
            panel = window
        }
        visible = true
        panel?.orderFrontRegardless()
    }
    func hide() { panel?.orderOut(nil); visible = false }
    func windowShouldClose(_ sender: NSWindow) -> Bool { hide(); return false }
    func resize(width: CGFloat, height: CGFloat) { panel?.setContentSize(NSSize(width: width, height: height)) }
}


struct GadgetView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var gadget: GadgetController
    @State private var hovering = false
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                PlanetView(state: model.state, desktop: true, onReset: { model.resetForm() })
                    .frame(height: max(190, geometry.size.height * 0.62))
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("TODAY").font(.caption.bold())
                        Spacer()
                        Text("LV. \(model.state.level) · \(model.state.form)").font(.caption).foregroundStyle(.secondary)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            let tasks = model.state.tasks.filter { !$0.later && !$0.done }
                            if tasks.isEmpty {
                                Text(model.state.tasks.contains { !$0.later && $0.done } ? "今天全部完成 ✦" : "打开 App，添加今天的任务")
                                    .font(.caption).foregroundStyle(.cyan)
                                if model.state.tasks.contains(where: { !$0.later && $0.done }) {
                                    Button("今天全部完成 ✦") { model.replayCelebration() }.font(.caption).buttonStyle(.bordered)
                                }
                            }
                            ForEach(tasks) { task in
                                Button { model.toggle(task.id) } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "circle").font(.title3)
                                        Text(task.title).lineLimit(2)
                                        Spacer(minLength: 0)
                                    }.font(.callout).padding(.vertical, 4).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel("完成 \(task.title)")
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }.padding(14).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 10).padding(.bottom, 10)
            }.foregroundStyle(.white).preferredColorScheme(.dark)
        }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    GadgetDragHandle().frame(width: 28, height: 28).help("拖动这里移动 gadget")
                    Button { gadget.openApp() } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("打开控制 App")
                    Button { gadget.hide() } label: { Image(systemName: "xmark") }.accessibilityLabel("隐藏桌面哥斯拉")
                }.buttonStyle(.plain).padding(10).background(.ultraThinMaterial, in: Capsule())
                    .padding(8).opacity(hovering ? 1 : 0).allowsHitTesting(hovering)
            }
            .onHover { hovering = $0 }
            .onReceive(timer) { _ in model.refresh() }
    }
}
private struct GadgetDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragHandleView() }
    func updateNSView(_ view: NSView, context: Context) {}
}
private final class DragHandleView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let symbol = NSImage(systemSymbolName: "arrow.up.and.down.and.arrow.left.and.right", accessibilityDescription: "移动桌面哥斯拉")
        symbol?.draw(in: bounds.insetBy(dx: 5, dy: 5))
    }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
}

private final class DesktopGadgetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class DesktopHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
