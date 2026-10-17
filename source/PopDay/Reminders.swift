import UserNotifications

struct Reminders {
    static let ids = ["popday.morning", "popday.afternoon", "popday.evening"]
    static func configure(_ enabled: Bool) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard enabled else { return }
        guard try await center.requestAuthorization(options: [.alert, .sound]) else {
            throw PlannerError.message("通知未获授权，请在系统设置中开启。")
        }
        let messages = [(9, "脑袋倒出来。", "说说今天想做什么，小怪物帮你收拾。"),
                        (14, "戳破一件小事。", "挑一个两分钟能开始的任务。动一下就算赢。"),
                        (20, "今天已经有进展。", "看看完成了什么。没做完的，明天还在。")]
        do {
            for (i, message) in messages.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = message.1; content.body = message.2; content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: message.0, minute: 0), repeats: true)
                try await center.add(UNNotificationRequest(identifier: ids[i], content: content, trigger: trigger))
            }
        } catch { center.removePendingNotificationRequests(withIdentifiers: ids); throw error }
    }
}
