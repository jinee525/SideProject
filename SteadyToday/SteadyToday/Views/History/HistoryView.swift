import SwiftUI
import SwiftData

struct HistoryView: View {
    private let calendar = Calendar.steadyMondayCalendar

    @State private var monthAnchor: Date = Date().startOfDay(calendar: .steadyMondayCalendar)
    @State private var selectedDay: Date = Date().startOfDay(calendar: .steadyMondayCalendar)

    @Query(sort: \ActionCheck.createdAt, order: .reverse) private var checks: [ActionCheck]
    @Query(sort: \TimeSession.createdAt, order: .reverse) private var timeSessions: [TimeSession]
    @Query(sort: \RoutineAction.todayOrder) private var actions: [RoutineAction]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    calendarHeader
                    calendarGrid
                    Spacer().frame(height: 14)
                    Divider()

                    HistoryDetailView(selectedDay: $selectedDay, monthAnchor: $monthAnchor)
                }
            }
            .navigationTitle("히스토리")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                let today = Date().startOfDay(calendar: calendar)
                monthAnchor = today
                selectedDay = today
            }
        }
    }

    // MARK: - Calendar UI

    private var calendarHeader: some View {
        HStack(spacing: 12) {
            Button {
                monthAnchor = addMonths(monthAnchor, delta: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle(monthAnchor))
                .font(.headline)

            Spacer()

            Button {
                monthAnchor = addMonths(monthAnchor, delta: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var calendarGrid: some View {
        let days = monthGridDays(anchor: monthAnchor)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return VStack(spacing: 8) {
            HStack {
                ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) { w in
                    Text(w)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days, id: \.self) { day in
                    if let day {
                        let isSelected = day == selectedDay
                        let isToday = day == Date().startOfDay(calendar: calendar)
                        Button {
                            selectedDay = day
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(calendar.component(.day, from: day))")
                                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 6)

                                let weekday = calendar.component(.weekday, from: day)
                                if weekday == 1 {
                                    if let percent = weeklyCompletionPercent(for: day) {
                                        Text("\(percent)%")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .padding(.bottom, 6)
                                    } else {
                                        Spacer(minLength: 0)
                                            .frame(height: 16)
                                    }
                                } else {
                                    if let percent = dailyCompletionPercent(for: day) {
                                        Text("\(percent)%")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .padding(.bottom, 6)
                                    } else {
                                        Spacer(minLength: 0)
                                            .frame(height: 16)
                                    }
                                }
                            }
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? AppColors.selectedBackground : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isToday ? AppColors.border : Color.clear, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .contentShape(Rectangle())
        .gesture(calendarSwipeGesture)
    }

    // MARK: - Data helpers (달력 셀 %용)

    private func dailyCompletionPercent(for day: Date) -> Int? {
        let dayStart = day.startOfDay(calendar: calendar)
        let todayStart = Date().startOfDay(calendar: calendar)
        if dayStart > todayStart { return nil }

        let dailyTargets = actions.filter { action in
            action.isActive(on: dayStart, calendar: calendar) && action.type == .weekdayRepeat && action.isScheduled(on: dayStart, calendar: calendar)
        }
        let dailyCompleted = checks.filter { check in
            guard check.day == dayStart, let action = check.action else { return false }
            return action.type == .weekdayRepeat && action.isActive(on: dayStart, calendar: calendar)
        }.count

        var timeBasedCompletedToday = 0
        for action in actions where action.isActive(on: dayStart, calendar: calendar) && action.type == .timeBased && action.isScheduled(on: dayStart, calendar: calendar) {
            let total = timeSessions
                .filter { $0.action?.persistentModelID == action.persistentModelID }
                .filter { $0.attributedDay == dayStart }
                .reduce(0) { $0 + $1.durationMinutes }
            if total >= action.timeTargetMinutes { timeBasedCompletedToday += 1 }
        }

        let weeklyNCompletedToday = actions.filter { action in
            guard action.type == .weeklyN, action.isActive(on: dayStart, calendar: calendar) else { return false }
            return checks.contains { $0.action?.persistentModelID == action.persistentModelID && $0.day == dayStart }
        }.count

        let totalTarget = dailyTargets.count + timeBasedCompletedToday + weeklyNCompletedToday
        if totalTarget == 0 { return nil }
        let totalCompleted = dailyCompleted + timeBasedCompletedToday + weeklyNCompletedToday
        return Int((Double(totalCompleted) / Double(totalTarget) * 100.0).rounded())
    }

    private func weeklyCompletionPercent(for day: Date) -> Int? {
        let dayStart = day.startOfDay(calendar: calendar)
        let todayStart = Date().startOfDay(calendar: calendar)
        if dayStart > todayStart { return nil }
        let weekday = calendar.component(.weekday, from: day)
        if weekday != 1 { return nil }

        let weeklyTargets = actions.filter { $0.isActive(on: dayStart, calendar: calendar) && $0.type == .weeklyN }
        if weeklyTargets.isEmpty { return nil }

        let thisWeek = day.weekInterval(calendar: calendar)
        var weeklyCompleted = 0
        for action in weeklyTargets {
            let actionChecks = checks.filter {
                guard $0.action?.persistentModelID == action.persistentModelID else { return false }
                return $0.day >= thisWeek.start && $0.day < thisWeek.end
            }
            if !actionChecks.isEmpty { weeklyCompleted += 1 }
        }
        return Int((Double(weeklyCompleted) / Double(weeklyTargets.count) * 100.0).rounded())
    }

    private func monthTitle(_ anchor: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy년 M월"
        return f.string(from: anchor)
    }

    private func addMonths(_ date: Date, delta: Int) -> Date {
        calendar.date(byAdding: .month, value: delta, to: date) ?? date
    }

    private func monthGridDays(anchor: Date) -> [Date?] {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor))!
        let monthRange = calendar.range(of: .day, in: .month, for: monthStart)!
        let daysInMonth = monthRange.count
        let appleWeekday = calendar.component(.weekday, from: monthStart)
        let firstIndex = (appleWeekday + 5) % 7

        var result: [Date?] = Array(repeating: nil, count: firstIndex)
        for day in 1...daysInMonth {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                result.append(d.startOfDay(calendar: calendar))
            }
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private var calendarSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) + 20 else { return }
                if value.translation.width < -40 {
                    monthAnchor = addMonths(monthAnchor, delta: 1)
                } else if value.translation.width > 40 {
                    monthAnchor = addMonths(monthAnchor, delta: -1)
                }
            }
    }
}
