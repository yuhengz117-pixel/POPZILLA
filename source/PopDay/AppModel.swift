import SwiftUI
import WidgetKit
import Combine

@MainActor final class AppModel: ObservableObject {
    @Published var state = DayState()
    @Published var error: String?
    @Published var busy = false
    @Published var additionMessage: String?
    @Published var lastAddedIDs: [UUID] = []
    @Published var lastDeleted: DayTask?
    @Published var localAIEnabled = UserDefaults.standard.object(forKey: "localAIEnabled") as? Bool ?? true
    @Published var aiEnabled = false
    @Published var hasAPIKey = false
    @Published var aiModel = UserDefaults.standard.string(forKey: "openAIModel") ?? "gpt-4.1-mini"
    @Published var aiConfigBusy = false
    @Published var aiConfigError: String?
    private var apiKey: String?
    let store: TaskStore
    init(store: TaskStore = TaskStore()) { self.store = store; refresh(); lastDeleted = state.deletedTasks?.last; loadAIConfiguration() }
    private func loadAIConfiguration() {
        do {
            apiKey = try OpenAIKeychain.read()
            if apiKey?.isEmpty != false { apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] }
            hasAPIKey = apiKey?.isEmpty == false
            let preferences = UserDefaults.standard
            aiEnabled = !localAIEnabled && hasAPIKey && (preferences.object(forKey: "openAIEnabled") == nil ? true : preferences.bool(forKey: "openAIEnabled"))
        } catch { aiConfigError = error.localizedDescription }
    }
    func setAIEnabled(_ enabled: Bool) {
        guard !enabled || hasAPIKey else { aiConfigError = "先填写并保存 Key。"; return }
        if enabled { setLocalAIEnabled(false) }; aiEnabled = enabled; UserDefaults.standard.set(enabled, forKey: "openAIEnabled")
    }
    func setLocalAIEnabled(_ enabled: Bool) {
        localAIEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "localAIEnabled")
        if enabled { aiEnabled = false; UserDefaults.standard.set(false, forKey: "openAIEnabled") }
    }
    func configureAI(key draft: String, model draftModel: String) async -> Bool {
        guard !aiConfigBusy else { return false }
        aiConfigBusy = true; aiConfigError = nil
        defer { aiConfigBusy = false }
        let proposed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = proposed.isEmpty ? (apiKey ?? "") : proposed
        let model = draftModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains(where: { $0.isWhitespace }), !model.isEmpty else { aiConfigError = "请填写有效的 Key 和模型名称。"; return false }
        do {
            try await validateOpenAIKey(key, model: model)
            try OpenAIKeychain.save(key)
            apiKey = key; hasAPIKey = true; aiModel = model
            UserDefaults.standard.set(model, forKey: "openAIModel")
            setAIEnabled(true)
            return true
        } catch { aiConfigError = error.localizedDescription; return false }
    }
    func refresh() {
        do { state = try store.load() } catch { self.error = "存储读取失败：\(error.localizedDescription)" }
    }
    func mutate(_ action: () throws -> DayState) {
        do { state = try action(); WidgetCenter.shared.reloadAllTimelines() }
        catch { self.error = error.localizedDescription }
    }
    func delete(_ id: UUID) {
        let task = state.tasks.first { $0.id == id }
        do { state = try store.delete(id); lastDeleted = task; error = nil; additionMessage = nil; WidgetCenter.shared.reloadAllTimelines() }
        catch { self.error = error.localizedDescription }
    }
    func clearCompleted() {
        mutate { try store.clearCompleted() }; lastDeleted = nil
    }
    func undoClearCompleted() { mutate { try store.undoClearCompleted() } }
    func undoDelete() {
        guard let task = lastDeleted else { return }
        do { state = try store.restore(task.id); lastDeleted = nil; error = nil; WidgetCenter.shared.reloadAllTimelines() }
        catch { self.error = error.localizedDescription }
    }
    func replayCelebration() { mutate { try store.replayCelebration() } }
    func resetForm() { mutate { try store.resetForm() } }
    func toggle(_ id: UUID) { mutate { try store.toggle(id) } }
    func promote(_ id: UUID) {
        mutate { try store.update { s in
            guard s.tasks.filter({ !$0.later && !$0.done }).count < 6,
                  let i = s.tasks.firstIndex(where: { $0.id == id }) else { return }
            s.tasks[i].later = false
        } }
    }
    func organize(_ text: String) async -> Bool {
        guard !busy else { return false }
        busy = true; error = nil; additionMessage = nil; lastAddedIDs = []
        defer { busy = false }
        let planner: any TaskPlanning
        if localAIEnabled { planner = OllamaPlanner() } else if aiEnabled {
            guard let key = apiKey, !key.isEmpty else { self.error = "请先在 AI 设置中保存 Key。"; return false }
            planner = OpenAIPlanner(key: key, model: aiModel)
        } else { planner = LocalPlanner() }
        do {
            let titles = try await planner.plan(text)
            guard !titles.isEmpty else { throw PlannerError.message("没有找到任务，再说一点？") }
            let existing = Set(try store.load().tasks.map(\.id))
            state = try store.append(titles)
            let added = state.tasks.filter { task in !existing.contains(task.id) && titles.contains(where: { $0.caseInsensitiveCompare(task.title) == .orderedSame }) }
            guard !added.isEmpty else {
                error = "这些事项已在列表中，没有新增；转写内容已保留。"
                return false
            }
            lastAddedIDs = added.map(\.id)
            let today = added.filter { !$0.later }.count, later = added.filter { $0.later }.count
            additionMessage = "已添加 \(added.count) 项 · Today \(today) · Later \(later)"
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func reminders(_ enabled: Bool) async {
        do { try await Reminders.configure(enabled); mutate { try store.update { $0.reminders = enabled } } }
        catch { self.error = error.localizedDescription }
    }
}
