import Foundation

@main struct KaijuChecks {
    static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = TaskStore(directory: folder)
        let legacy = #"{"tasks":[{"id":"11111111-1111-1111-1111-111111111111","title":"old task","done":false,"later":false,"xp":20}],"xp":80,"day":0,"reminders":false}"#
        let migrated = try JSONDecoder().decode(DayState.self, from: Data(legacy.utf8))
        precondition(migrated.xp == 80 && migrated.evolutions == 0 && migrated.buildings == 0)
        let grow = DayTask(title: "Grow", rewardKind: .evolution)
        let stomp = DayTask(title: "Stomp", rewardKind: .rampage)
        try store.update { $0.tasks = [grow, stomp]; $0.xp = 80 }
        var state = try store.toggle(grow.id)
        precondition(state.xp == 100 && state.level == 2 && state.evolutions == 1 && state.lastReward?.kind == .evolution)
        state = try store.toggle(stomp.id)
        precondition(state.xp == 120 && state.buildings == 1 && state.lastReward?.kind == .rampage)
        state = try store.load()
        precondition(state.evolutions == 1 && state.buildings == 1)
        state = try store.toggle(stomp.id)
        precondition(state.xp == 100 && state.buildings == 0 && state.lastReward == nil)
        state = try store.toggle(stomp.id)
        precondition(state.lastReward?.kind == .rampage && state.buildings == 1)
        state = try store.toggle(grow.id)
        precondition(state.evolutions == 0)
        print("PASS: legacy migration, evolution unlock, growth level, city destruction, persistence, undo and stable reward")
    }
}
