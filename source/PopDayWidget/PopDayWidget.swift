import SwiftUI
import WidgetKit
import AppIntents

struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "切换任务完成状态"
    @Parameter(title: "任务 ID") var taskID: String
    init() {}
    init(_ id: UUID) { taskID = id.uuidString }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: taskID) { try TaskStore().toggle(id) }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
struct DayEntry: TimelineEntry { let date: Date; let state: DayState }
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), state: DayState(tasks: [DayTask(title: "把脑袋倒出来"), DayTask(title: "开始一件小事")]))
    }
    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(Date().addingTimeInterval(300))))
    }
    private func entry() -> DayEntry { DayEntry(date: Date(), state: (try? TaskStore().load()) ?? DayState()) }
}
struct WidgetView: View {
    let entry: DayEntry
    @Environment(\.widgetFamily) var family
    private let cyan = Color(red: 0.25, green: 0.85, blue: 1)
    private var tasks: [DayTask] { entry.state.tasks.filter { !$0.later } }
    private var limit: Int { family == .systemLarge ? 5 : family == .systemSmall ? 1 : 3 }
    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            if tasks.isEmpty { Text("打开 POPZILLA，喂养巨兽。").font(.caption) }
            ForEach(tasks.prefix(limit)) { task in
                Button(intent: CompleteTaskIntent(task.id)) {
                    HStack(spacing: 6) {
                        Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                        Text(task.title).strikethrough(task.done).lineLimit(1)
                        Spacer(minLength: 0)
                    }.font(.caption).foregroundStyle(task.done ? .gray : .white)
                }.buttonStyle(.plain)
            }
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("POPZILLA").font(.caption.bold()); Spacer(); Text("LV. \(entry.state.level)").font(.caption2).foregroundStyle(cyan) }
            if family == .systemMedium {
                HStack(spacing: 12) {
                    KaijuScene(xp: entry.state.xp, compact: true, evolutions: entry.state.evolutions, buildings: entry.state.buildings).frame(width: 125, height: 82).clipShape(RoundedRectangle(cornerRadius: 8))
                    list
                }
            } else {
                KaijuScene(xp: entry.state.xp, compact: true, evolutions: entry.state.evolutions, buildings: entry.state.buildings).frame(height: family == .systemLarge ? 105 : 62).clipShape(RoundedRectangle(cornerRadius: 8))
                list
            }
            Spacer(minLength: 0)
            Text("\(entry.state.xp) XP · \(entry.state.form)").font(.caption2).foregroundStyle(cyan)
        }.containerBackground(Color(white: 0.045), for: .widget)
    }

}
@main struct PopDayWidget: Widget {
    let kind = "PopDayWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { WidgetView(entry: $0) }
            .configurationDisplayName("POPZILLA")
            .description("每天六件小事，点一下完成。")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
