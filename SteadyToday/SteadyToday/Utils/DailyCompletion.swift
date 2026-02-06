import Foundation
import SwiftData

struct DailyProgress {
    let completed: Int
    let target: Int
    var percentage: Int {
        guard target > 0 else { return 0 }
        return Int((Double(completed) / Double(target) * 100.0).rounded())
    }
}

enum DailyCompletionCalculator {
    static func progress(
        for day: Date,
        actions: [RoutineAction],
        checks: [ActionCheck],
        timeSessions: [TimeSession],
        calendar: Calendar = .steadyMondayCalendar
    ) -> DailyProgress? {
        let dayStart = day.startOfDay(calendar: calendar)

        let dailyTargets = actions.filter { action in
            action.isActive(on: dayStart, calendar: calendar)
                && action.type == .weekdayRepeat
                && action.isScheduled(on: dayStart, calendar: calendar)
        }
        let dailyCompleted = checks.filter { check in
            guard check.day == dayStart, let action = check.action else { return false }
            return action.type == .weekdayRepeat && action.isActive(on: dayStart, calendar: calendar)
        }.count

        let timeTargets = actions.filter { action in
            action.isActive(on: dayStart, calendar: calendar)
                && action.type == .timeBased
                && action.isScheduled(on: dayStart, calendar: calendar)
        }
        var timeBasedCompleted = 0
        for action in timeTargets {
            let total = timeSessions
                .filter { $0.action?.persistentModelID == action.persistentModelID }
                .filter { $0.attributedDay == dayStart }
                .reduce(0) { $0 + $1.durationMinutes }
            if total >= action.timeTargetMinutes { timeBasedCompleted += 1 }
        }

        let weeklyNCompleted = actions.filter { action in
            guard action.type == .weeklyN, action.isActive(on: dayStart, calendar: calendar) else { return false }
            return checks.contains { $0.action?.persistentModelID == action.persistentModelID && $0.day == dayStart }
        }.count

        let totalTarget = dailyTargets.count + timeTargets.count + weeklyNCompleted
        if totalTarget == 0 { return nil }
        let totalCompleted = dailyCompleted + timeBasedCompleted + weeklyNCompleted
        return DailyProgress(completed: totalCompleted, target: totalTarget)
    }
}
