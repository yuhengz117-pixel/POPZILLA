import SwiftUI
import Combine
import AppKit

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var gadget: GadgetController
    @Environment(\.openWindow) private var openWindow
    @StateObject private var speech = SpeechInput()
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var dump = ""
    @State private var submitQueued = false
    @State private var showAISettings = false
    @State private var keyDraft = ""
    @State private var aiModelDraft = "gpt-4.1-mini"
    @State private var voicePrefix = ""
    @State private var lastVoiceDisplay = ""
    @State private var laterExpanded = false
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let ink = Color(red: 0.08, green: 0.08, blue: 0.09)
    private let acid = Color(red: 0.25, green: 0.85, blue: 1)
    var body: some View {
        ZStack {
            ink.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { Text("POPZILLA").font(.system(size: 24, weight: .black, design: .rounded)); Spacer(); Button { keyDraft = ""; aiModelDraft = model.aiModel; model.aiConfigError = nil; showAISettings = true } label: { Image(systemName: "gearshape") }.buttonStyle(.plain).help("App 与 gadget 设置").accessibilityLabel("App 与 gadget 设置").disabled(model.busy || speech.recording || speech.processing) }.padding(.horizontal, 24).padding(.top, 16)
                if !gadget.visible { PlanetView(state: model.state, onReset: { model.resetForm() }).frame(maxWidth: .infinity).frame(height: 300).padding(.horizontal, 20) }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("LV. \(model.state.level) · \(model.state.form)").font(.headline)
                            Text("\(model.state.xp) XP · 踏平 \(model.state.buildings) 栋楼").font(.caption.monospaced()).foregroundStyle(.gray)
                        }
                        Spacer()
                        Text("💥").font(.caption2).foregroundStyle(acid)
                    }
                    ProgressView(value: model.state.nextLevelProgress).tint(acid)
                    HStack { Text("TODAY").font(.headline); Spacer(); Text("✦") .font(.caption).foregroundStyle(.gray) }
                    if model.state.tasks.filter({ !$0.later && !$0.done }).isEmpty {
                        Text(model.state.tasks.contains(where: { !$0.later && $0.done }) ? "今天的事项都完成了 ✦" : "这里空空的。先把脑袋倒出来 ↓").foregroundStyle(acid).padding(.vertical, 20)
                    }
                    if model.state.tasks.contains(where: { !$0.later }), model.state.tasks.filter({ !$0.later }).allSatisfy({ $0.done }) {
                        Button("今天全部完成 ✦") { model.replayCelebration() }.buttonStyle(.borderedProminent).tint(acid)
                    }
                    ForEach(model.state.tasks.filter { !$0.later && !$0.done }) { task in
                        HStack(spacing: 10) {
                            Button { model.toggle(task.id) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "circle").font(.title2)
                                    Text(task.title); Spacer()
                                    if task.id == model.state.tasks.first(where: { !$0.later && !$0.done })?.id { Text("NOW").font(.caption.bold()).foregroundStyle(acid) }
                                }.padding(.vertical, 14).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("\(task.title)，未完成")
                            deleteButton(task)
                        }.padding(.horizontal, 14).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    let completed = model.state.tasks.filter { $0.done }
                    if !completed.isEmpty {
                        HStack(alignment: .top) {
                        DisclosureGroup("已完成 · \(completed.count)") {
                            ForEach(completed) { task in
                                HStack {
                                    Button { model.toggle(task.id) } label: {
                                        HStack { Image(systemName: "checkmark.circle.fill"); Text(task.title).strikethrough(); Spacer() }.padding(.vertical, 6)
                                    }.buttonStyle(.plain).foregroundStyle(.gray).accessibilityLabel("\(task.title)，已完成，点击撤销")
                                    deleteButton(task)
                                }
                            }
                        }.tint(acid)
                        Button("清空") { model.clearCompleted() }.font(.caption).buttonStyle(.bordered).accessibilityLabel("清空已完成事项")
                        }
                    }
                    if !(model.state.lastClearedCompleted ?? []).isEmpty {
                        HStack { Text("已清空完成事项").font(.caption).foregroundStyle(.gray); Spacer(); Button("撤销清空") { model.undoClearCompleted() } }
                    }
                    let later = model.state.tasks.filter { $0.later && !$0.done }
                    if !later.isEmpty {
                        DisclosureGroup("LATER", isExpanded: $laterExpanded) {
                            ForEach(later) { task in
                                HStack { Text(task.title); Spacer(); Button("移到今天") { model.promote(task.id) }.disabled(model.state.tasks.filter { !$0.later && !$0.done }.count >= 6); deleteButton(task) }.padding(.vertical, 6)
                            }
                        }.tint(acid)
                    }
                    if model.lastDeleted != nil {
                        HStack { Text("已删除事项").font(.caption).foregroundStyle(.gray); Spacer(); Button("撤销删除") { model.undoDelete() } }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        TaskInputEditor(text: $dump, onSubmit: submitDump)
                            .frame(height: 88).padding(8).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .accessibilityLabel("今日任务输入")
                        HStack {
                            Button { if speech.recording { speech.stop() } else { model.error = nil; if dump != lastVoiceDisplay { voicePrefix = dump }; Task { await speech.start() } } } label: {
                                Label(speech.recording ? "停止并添加" : speech.processing ? "识别中…" : "语音输入", systemImage: speech.recording ? "stop.fill" : "mic.fill").labelStyle(.iconOnly)
                            }.tint(speech.recording ? .red : acid).disabled(model.busy || speech.processing)
                            Spacer()
                            Button {
                                submitDump()
                            } label: {
                                if model.busy { ProgressView().controlSize(.small) }
                                else { Image(systemName: "return") }
                            }.accessibilityLabel(model.busy ? "整理中" : "提交任务").help("Enter 提交").disabled(!canSubmitDump)
                        }
                    }
                    if let message = model.additionMessage { Text(message).font(.caption).foregroundStyle(acid) }
                    if let error = model.error ?? speech.error { Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
                    Text("✦") .font(.caption2).foregroundStyle(.gray)
                }.padding(24)
            }
            }
        }.preferredColorScheme(.dark).frame(minWidth: 390, minHeight: 560)
            .onReceive(timer) { _ in model.refresh() }
            .onChange(of: speech.transcript) { _, text in
                dump = voicePrefix + (voicePrefix.isEmpty || text.isEmpty ? "" : "\n") + text
            }
            .onChange(of: speech.completionID) { _, _ in
                let text = speech.completedTranscript
                guard !text.isEmpty else { return }
                Task { if await model.organize(text) { lastVoiceDisplay = dump } }
            }
            .onChange(of: model.lastAddedIDs) { _, ids in
                if model.state.tasks.contains(where: { ids.contains($0.id) && $0.later }) { laterExpanded = true }
            }
            .sheet(isPresented: $showAISettings) { aiSettingsSheet }
            .onAppear { gadget.configure(model: model, openApp: { openWindow(id: "main"); NSApplication.shared.activate(ignoringOtherApps: true) }) }
            .onDisappear { speech.cancel() }
    }
    private var aiSettingsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App 与桌面哥斯拉").font(.title2.bold())
            Toggle("显示桌面哥斯拉", isOn: Binding(get: { gadget.visible }, set: { $0 ? gadget.show() : gadget.hide() }))
            Toggle("打开 App 时显示桌面哥斯拉", isOn: $gadget.showOnLaunch)
            HStack {
                Text("窗口大小").font(.caption)
                Button("小") { gadget.resize(width: 320, height: 380) }
                Button("中") { gadget.resize(width: 360, height: 440) }
                Button("大") { gadget.resize(width: 460, height: 550) }
            }
            Button("重置哥斯拉形态") { model.resetForm() }
            Text("双击地球恢复追踪哥斯拉；拖动地球自由观察，滚轮缩放；四向箭头移动 gadget。").font(.caption).foregroundStyle(.gray)
            Divider()
            Text("让 AI 把输入和语音转写整理成独立待办。").font(.callout).foregroundStyle(.gray)
            Toggle("本地 AI · Qwen3 0.6B", isOn: Binding(get: { model.localAIEnabled }, set: { model.setLocalAIEnabled($0) }))
            Text("模型在这台 Mac 上运行，任务整理无需 Key、没有 API 费用。关闭后使用规则整理。语音识别仍由 Apple 提供。")
                .font(.caption).foregroundStyle(.gray)
            DisclosureGroup("可选：OpenAI（按用量收费）") {
            SecureField(model.hasAPIKey ? "已保存 Key；留空沿用" : "OpenAI API Key", text: $keyDraft)
                .textFieldStyle(.roundedBorder).accessibilityLabel("OpenAI API Key")
            TextField("模型", text: $aiModelDraft).textFieldStyle(.roundedBorder).accessibilityLabel("OpenAI 模型")
            Toggle("启用 AI 整理", isOn: Binding(get: { model.aiEnabled }, set: { model.setAIEnabled($0) })).disabled(!model.hasAPIKey || model.aiConfigBusy)
            Text("Key 保存到 macOS 钥匙串。输入文字发往 OpenAI，按 API 用量计费。语音识别仍由 Apple 提供。").font(.caption).foregroundStyle(.gray)
            Link("创建 OpenAI API Key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                Button(model.aiConfigBusy ? "检查连接…" : "保存并启用") {
                    Task { if await model.configureAI(key: keyDraft, model: aiModelDraft) { keyDraft = ""; showAISettings = false } }
                }.buttonStyle(.borderedProminent).disabled(model.aiConfigBusy || (!model.hasAPIKey && keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || aiModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error = model.aiConfigError { Text(error).font(.caption).foregroundStyle(.orange) }
            HStack {
                Button("完成") { keyDraft = ""; showAISettings = false }.disabled(model.aiConfigBusy)
                Spacer()

            }
        }.padding(24).frame(width: 410).interactiveDismissDisabled(model.aiConfigBusy)
    }
    private var canSubmitDump: Bool {
        !dump.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !submitQueued && !model.busy && !speech.recording && !speech.processing
    }
    private func submitDump() {
        guard canSubmitDump else { return }
        let text = dump
        submitQueued = true
        Task {
            defer { submitQueued = false }
            if await model.organize(text), dump == text { dump = "" }
        }
    }
    private func deleteButton(_ task: DayTask) -> some View {
        Button(role: .destructive) { model.delete(task.id) } label: {
            Image(systemName: "trash").foregroundStyle(.gray).frame(width: 30, height: 30).contentShape(Rectangle())
        }.buttonStyle(.plain).help("删除事项").accessibilityLabel("删除 \(task.title)")
    }
}

/// A plain multiline task editor with Enter submission and IME-safe composition.
private struct TaskInputEditor: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let editor = SubmitTextView(frame: NSRect(x: 0, y: 0, width: 360, height: 88))
        editor.isEditable = true
        editor.isSelectable = true
        editor.minSize = NSSize(width: 0, height: 88)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.containerSize = NSSize(width: 360, height: CGFloat.greatestFiniteMagnitude)
        editor.isRichText = false
        editor.drawsBackground = false
        editor.textColor = .white
        editor.font = .systemFont(ofSize: 14)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainerInset = NSSize(width: 2, height: 4)
        editor.allowsUndo = true
        editor.setAccessibilityLabel("今日任务输入")
        editor.delegate = context.coordinator
        scroll.documentView = editor
        updateNSView(scroll, context: context)
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? SubmitTextView else { return }
        if editor.string != text && !editor.hasMarkedText() { editor.string = text }
        editor.onSubmit = onSubmit
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TaskInputEditor
        init(_ parent: TaskInputEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }
    }
}
private final class SubmitTextView: NSTextView {
    var onSubmit: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
    override func keyDown(with event: NSEvent) {
        let isEnter = event.keyCode == 36 || event.keyCode == 76
        let newlineModifiers: NSEvent.ModifierFlags = [.shift, .option, .control, .command]
        if isEnter && event.modifierFlags.intersection(newlineModifiers).isEmpty && !hasMarkedText() {
            onSubmit?()
            return
        }
        super.keyDown(with: event)
    }
}
