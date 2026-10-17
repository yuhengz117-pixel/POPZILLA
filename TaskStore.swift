import Foundation
import Darwin

enum KaijuReward: String, Codable { case evolution, rampage }
struct KaijuEvent: Codable, Equatable {
    var id = UUID()
    var date = Date()
    var kind: KaijuReward
    var taskID: UUID? = nil
    var xp: Int
}

struct DayCelebration: Codable, Equatable {
    var id = UUID()
    var date = Date()
}

struct DayTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var done = false
    var later = false
    var xp = 20
    var rewardKind: KaijuReward?
}
struct DayState: Codable, Equatable {
    var tasks: [DayTask] = []
    var xp = 0
    var day = Calendar.current.startOfDay(for: Date())
    var reminders = false
    var lastReward: KaijuEvent?
    var destructionCount: Int?
    var evolutionCount: Int?
    var deletedTasks: [DayTask]?
    var lastClearedCompleted: [UUID]?
    var formResetXP: Int?
    var growthXP: Int { max(0, xp - (formResetXP ?? 0)) }
    var celebrationDay: Date?
    var lastCelebration: DayCelebration?
    var evolutions: Int { evolutionCount ?? 0 }
    var buildings: Int { destructionCount ?? 0 }
    var level: Int { 1 + growthXP / 100 }
    var form: String { growthXP < 40 ? "Original · 小" : growthXP < 100 ? "Original · 大" : growthXP < 300 ? "蓝色觉醒" : growthXP < 700 ? "紫色过载" : "红莲" }
    var nextLevelProgress: Double { Double(growthXP % 100) / 100 }
    var momentum: Int { tasks.filter { $0.done && !$0.later }.count }
    mutating func rollDay(_ now: Date = Date()) {
        let today = Calendar.current.startOfDay(for: now)
        if day != today {
            tasks.removeAll { $0.done }
            for i in tasks.indices { tasks[i].later = true }
            day = today
            lastCelebration = nil
        }
    }
}
struct TaskStore {
    static let group = "group.com.popday.prototype"
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.group)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PopDay")
    }
    private func locked<T>(_ action: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fd = open(directory.appendingPathComponent("state.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { flock(fd, LOCK_UN) }
        return try action()
    }
    private func read() throws -> DayState {
        let url = directory.appendingPathComponent("state.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return DayState() }
        return try JSONDecoder().decode(DayState.self, from: Data(contentsOf: url))
    }
    @discardableResult func update(_ mutation: (inout DayState) -> Void) throws -> DayState {
        try locked {
            var state = try read()
            state.rollDay()
            mutation(&state)
            try JSONEncoder().encode(state).write(to: directory.appendingPathComponent("state.json"), options: .atomic)
            return state
        }
    }
    func load() throws -> DayState { try update { _ in } }
    @discardableResult func toggle(_ id: UUID) throws -> DayState {
        try update { state in
            guard let i = state.tasks.firstIndex(where: { $0.id == id }) else { return }
            state.tasks[i].done.toggle()
            if state.tasks[i].done {
                if state.tasks[i].rewardKind == nil {
                    state.tasks[i].rewardKind = Int.random(in: 0..<100) < 35 ? .evolution : .rampage
                }
                let kind = state.tasks[i].rewardKind ?? .rampage
                state.lastReward = KaijuEvent(kind: kind, taskID: id, xp: state.tasks[i].xp)
                if kind == .rampage { state.destructionCount = state.buildings + 1 }
                else { state.evolutionCount = state.evolutions + 1 }
            } else {
                if state.tasks[i].rewardKind == .rampage { state.destructionCount = max(0, state.buildings - 1) }
                if state.tasks[i].rewardKind == .evolution { state.evolutionCount = max(0, state.evolutions - 1) }
                state.lastReward = nil
            }
            state.xp = max(0, state.xp + (state.tasks[i].done ? state.tasks[i].xp : -state.tasks[i].xp))

        }
    }
    @discardableResult func replayCelebration() throws -> DayState {
        try update { state in
            let today = state.tasks.filter { !$0.later }
            guard !today.isEmpty, today.allSatisfy({ $0.done }) else { return }
            state.lastCelebration = DayCelebration()
            state.celebrationDay = state.day
        }
    }
    @discardableResult func resetForm() throws -> DayState {
        try update { $0.formResetXP = $0.xp }
    }
    @discardableResult func delete(_ id: UUID) throws -> DayState {
        try update { state in
            guard let i = state.tasks.firstIndex(where: { $0.id == id }) else { return }
            let task = state.tasks.remove(at: i)
            var deleted = state.deletedTasks ?? []
            deleted.append(task); state.deletedTasks = deleted
            if state.lastReward?.taskID == id { state.lastReward = nil }
        }
    }
    @discardableResult func clearCompleted() throws -> DayState {
        try update { state in
            let completed = state.tasks.filter { $0.done }
            guard !completed.isEmpty else { return }
            state.lastClearedCompleted = completed.map(\.id)
            state.deletedTasks = (state.deletedTasks ?? []) + completed
            state.tasks.removeAll { $0.done }
            if let id = state.lastReward?.taskID, completed.contains(where: { $0.id == id }) { state.lastReward = nil }
        }
    }
    @discardableResult func undoClearCompleted() throws -> DayState {
        try update { state in
            let ids = Set(state.lastClearedCompleted ?? [])
            guard !ids.isEmpty else { return }
            let restored = (state.deletedTasks ?? []).filter { ids.contains($0.id) }
            state.tasks.append(contentsOf: restored.filter { task in !state.tasks.contains(where: { $0.id == task.id }) })
            state.deletedTasks?.removeAll { ids.contains($0.id) }
            state.lastClearedCompleted = nil
        }
    }
    @discardableResult func restore(_ id: UUID) throws -> DayState {
        try update { state in
            guard var deleted = state.deletedTasks, let i = deleted.firstIndex(where: { $0.id == id }) else { return }
            var task = deleted.remove(at: i)
            if !task.done && state.tasks.filter({ !$0.later && !$0.done }).count >= 6 { task.later = true }
            state.deletedTasks = deleted; state.tasks.append(task)
        }
    }
    @discardableResult func append(_ titles: [String]) throws -> DayState {
        try update { state in
            var slots = max(0, 6 - state.tasks.filter { !$0.later && !$0.done }.count)
            for title in titles {
                let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty, !state.tasks.contains(where: { $0.title.caseInsensitiveCompare(clean) == .orderedSame }) else { continue }
                state.tasks.append(DayTask(title: clean, later: slots == 0))
                slots = max(0, slots - 1)
            }
        }
    }
}
