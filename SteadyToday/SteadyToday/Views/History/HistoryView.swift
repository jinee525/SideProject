import SwiftUI
import SwiftData

enum HistoryTab: String, CaseIterable {
    case summary = "요약"
    case calendar = "달력"
    case log = "로그"
}

struct HistoryView: View {
    private let calendar = Calendar.steadyMondayCalendar

    @State private var selectedTab: HistoryTab = .calendar
    @State private var monthAnchor: Date = Date().startOfDay(calendar: .steadyMondayCalendar)
    @State private var selectedDay: Date = Date().startOfDay(calendar: .steadyMondayCalendar)

    @Query(sort: \ActionCheck.createdAt, order: .reverse) private var checks: [ActionCheck]
    @Query(sort: \TimeSession.createdAt, order: .reverse) private var timeSessions: [TimeSession]
    @Query(sort: \RoutineAction.todayOrder) private var actions: [RoutineAction]

    var body: some View {
        MainTabLayout(title: "돌아보기") {
            VStack(spacing: 0) {
                // 탭: 요약 | 달력 | 로그
                Picker("", selection: $selectedTab) {
                    ForEach(HistoryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                switch selectedTab {
                case .summary:
                    ScrollView {
                        HistorySummaryView()
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                    }
                    .scrollContentBackground(.hidden)

                case .calendar:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            BorderedCardView {
                                VStack(alignment: .leading, spacing: 0) {
                                    calendarHeader
                                    calendarGrid
                                }
                            }
                            .padding(.horizontal, 16)

                            HistoryDetailView(selectedDay: $selectedDay, monthAnchor: $monthAnchor)
                        }
                        .padding(.top, 8)
                    }
                    .scrollContentBackground(.hidden)

                case .log:
                    HistoryDailyLogView()
                }
            }
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
        .padding(.top, 0)
        .padding(.bottom, 12)
    }

    private var calendarGrid: some View {
        let days = monthGridDays(anchor: monthAnchor)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let todayStart = Date().startOfDay(calendar: calendar)
        let selectedStart = selectedDay.startOfDay(calendar: calendar)

        return VStack(spacing: 8) {
            HStack {
                ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) { w in
                    Text(w)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        let dayStart = day.startOfDay(calendar: calendar)
                        let isSelected = dayStart == selectedStart
                        let isToday = dayStart == todayStart
                        Button {
                            selectedDay = dayStart
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(calendar.component(.day, from: dayStart))")
                                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 6)

                                if let percent = dailyCompletionPercent(for: dayStart) {
                                    Text("\(percent)%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.bottom, 6)
                                } else {
                                    Spacer(minLength: 0)
                                        .frame(height: 16)
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
            .padding(.bottom, 12)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(calendarSwipeGesture)
    }

    // MARK: - Data helpers (달력 셀 %용)

    private func dailyCompletionPercent(for day: Date) -> Int? {
        let dayStart = day.startOfDay(calendar: calendar)
        let todayStart = Date().startOfDay(calendar: calendar)
        if dayStart > todayStart { return nil }
        return DailyCompletionCalculator
            .progress(
                for: dayStart,
                actions: actions,
                checks: checks,
                timeSessions: timeSessions,
                calendar: calendar
            )?
            .percentage
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
