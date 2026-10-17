import Foundation

@main struct StoreChecks {
    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = TaskStore(directory: folder)
        var state = try store.append((0..<9).map { "Task \($0)" })
        precondition(state.tasks.filter { !$0.later }.count == 6)
        precondition(state.tasks.filter { $0.later }.count == 3)
        state = try store.append(["Task 0", "  "])
        precondition(state.tasks.count == 9)
        let id = state.tasks[0].id
        state = try store.toggle(id)
        precondition(state.xp == 20 && state.momentum == 1)
        state = try store.toggle(id)
        precondition(state.xp == 0 && state.momentum == 0)
        try store.update { $0.day = Date.distantPast; $0.tasks[0].done = true; $0.xp = 20 }
        state = try store.load()
        precondition(state.tasks.count == 8 && state.tasks.allSatisfy { $0.later } && state.xp == 20)
        DispatchQueue.concurrentPerform(iterations: 30) { index in
            do { try store.append(["Concurrent \(index)"]) } catch { fatalError("\(error)") }
        }
        state = try store.load()
        precondition(state.tasks.count == 38)
        let local = try await LocalPlanner().plan("洗衣服，然后回复邮件；运动\n读书")
        precondition(local == ["洗衣服", "回复邮件", "运动", "读书"])
        print("PASS: Today cap, Later overflow, duplicates, XP undo, persistence, rollover, concurrent writers, local planner")
    }
}
