import SwiftUI
import SwiftData

/// 상단 요약: 이번 주의 꾸준함(오늘 기준 주) + 카테고리별 달성률
struct HistorySummaryView: View {
    private let calendar = Calendar.steadyMondayCalendar

    @Query(sort: \ActionCheck.createdAt, order: .reverse) private var checks: [ActionCheck]
    @Query(sort: \TimeSession.createdAt, order: .reverse) private var timeSessions: [TimeSession]
    @Query(sort: \RoutineAction.todayOrder) private var actions: [RoutineAction]
    @Query(sort: \MandalartCategory.sortOrder) private var categories: [MandalartCategory]

    init() {
        let year = Calendar.steadyMondayCalendar.component(.year, from: Date())
        _categories = Query(
            filter: #Predicate<MandalartCategory> { $0.planYear?.year == year },
            sort: [SortDescriptor(\.sortOrder, order: .forward)]
        )
    }

    private var todayWeekInterval: DateInterval { Date().weekInterval(calendar: calendar) }
    private var todayStart: Date { Date().startOfDay(calendar: calendar) }
    private var weekDays: [Date] { getWeekDays(for: todayWeekInterval) }
    private var actionsForThisWeek: [RoutineAction] {
        actions.filter { action in
            weekDays.contains { day in
                action.isActive(on: day, calendar: calendar) && (action.type == .weeklyN || action.isScheduled(on: day, calendar: calendar))
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            weekConsistencyTable()
            if !categoryProgresses.isEmpty {
                categoryGrid(categoryProgresses: categoryProgresses)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    // MARK: - Data

    private var categoryProgresses: [CategoryProgress] {
        calculateCategoryProgresses(for: todayStart)
    }

    private func getWeekDays(for weekInterval: DateInterval) -> [Date] {
        var days: [Date] = []
        var currentDate = weekInterval.start
        while currentDate < weekInterval.end {
            days.append(currentDate.startOfDay(calendar: calendar))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        return days
    }

    private func isActionCompletedOnDay(_ action: RoutineAction, day: Date) -> Bool {
        let dayStart = day.startOfDay(calendar: calendar)
        return checks.contains { $0.action?.persistentModelID == action.persistentModelID && $0.day == dayStart }
    }

    private func calculateCategoryProgresses(for day: Date) -> [CategoryProgress] {
        let defaultIntervalStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: todayStart), month: 1, day: 1))!
        return categories.map { category in
            var actionPercentages: [Int] = []
            for action in category.actions {
                guard action.isActive else { continue }
                let intervalStart = action.startDate?.startOfDay(calendar: calendar) ?? defaultIntervalStart
                let intervalEnd: Date
                if let endDate = action.endDate {
                    let endDay = endDate.startOfDay(calendar: calendar)
                    intervalEnd = endDay < todayStart ? endDay : todayStart
                } else {
                    intervalEnd = todayStart
                }
                guard intervalStart <= intervalEnd else { continue }
                var total = 0, completed = 0
                switch action.type {
                case .weekdayRepeat:
                    var d = intervalStart
                    while d <= intervalEnd {
                        let dayStart = d.startOfDay(calendar: calendar)
                        if action.isActive(on: dayStart, calendar: calendar), action.isScheduled(on: dayStart, calendar: calendar) {
                            total += 1
                            if dayStart <= todayStart, checks.contains(where: { $0.day == dayStart && $0.action?.persistentModelID == action.persistentModelID }) {
                                completed += 1
                            }
                        }
                        d = calendar.date(byAdding: .day, value: 1, to: d) ?? d
                    }
                case .timeBased:
                    var d = intervalStart
                    while d <= intervalEnd {
                        let dayStart = d.startOfDay(calendar: calendar)
                        if action.isActive(on: dayStart, calendar: calendar), action.isScheduled(on: dayStart, calendar: calendar) {
                            total += 1
                            if dayStart <= todayStart {
                                let mins = timeSessions
                                    .filter { $0.action?.persistentModelID == action.persistentModelID && $0.attributedDay == dayStart }
                                    .reduce(0) { $0 + $1.durationMinutes }
                                if mins >= action.timeTargetMinutes { completed += 1 }
                            }
                        }
                        d = calendar.date(byAdding: .day, value: 1, to: d) ?? d
                    }
                case .weeklyN:
                    let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: intervalStart))!
                    var w = weekStart
                    var weekCount = 0
                    while w <= intervalEnd {
                        weekCount += 1
                        w = calendar.date(byAdding: .day, value: 7, to: w) ?? w
                    }
                    total += weekCount * action.weeklyTargetN
                    w = weekStart
                    while w <= intervalEnd {
                        let weekEnd = calendar.date(byAdding: .day, value: 7, to: w)!
                        if w <= todayStart {
                            let weekChecks = checks.filter { check in
                                guard check.action?.persistentModelID == action.persistentModelID else { return false }
                                let ds = check.day.startOfDay(calendar: calendar)
                                return ds >= w && ds < weekEnd
                            }
                            completed += min(action.weeklyTargetN, weekChecks.count)
                        }
                        w = calendar.date(byAdding: .day, value: 7, to: w) ?? w
                    }
                }
                if total > 0 {
                    actionPercentages.append(Int((Double(completed) / Double(total) * 100.0).rounded()))
                }
            }
            guard !actionPercentages.isEmpty else {
                return CategoryProgress(category: category, completed: 0, total: 0, percentage: 0)
            }
            let sumPct = actionPercentages.reduce(0, +)
            let percentage = sumPct / actionPercentages.count
            return CategoryProgress(category: category, completed: sumPct, total: actionPercentages.count, percentage: percentage)
        }.filter { $0.total > 0 }
    }

    private func dayLabel(for day: Date) -> String {
        let weekday = calendar.component(.weekday, from: day)
        let labels = ["일", "월", "화", "수", "목", "금", "토"]
        return labels[(weekday - 1) % 7]
    }

    private func dayNumber(for day: Date) -> String {
        "\(calendar.component(.day, from: day))"
    }

    // MARK: - UI

    private struct CategoryProgress: Identifiable {
        let category: MandalartCategory
        let completed: Int
        let total: Int
        let percentage: Int
        var id: PersistentIdentifier { category.persistentModelID }
    }

    @ViewBuilder
    private func weekConsistencyTable() -> some View {
        if !actionsForThisWeek.isEmpty {
            let gridLine = AppColors.gridLine
            SectionCardView(title: "🏃 이번 주의 꾸준함") {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            Text("")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)
                                .padding(.horizontal, 8)
                                .overlay(alignment: .trailing) { Rectangle().fill(gridLine).frame(width: 1).frame(maxHeight: .infinity) }
                            ForEach(Array(weekDays.enumerated()), id: \.element) { index, day in
                                let isToday = day.startOfDay(calendar: calendar) == todayStart
                                VStack(spacing: 4) {
                                    Text(dayLabel(for: day))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(isToday ? AppColors.label : .secondary)
                                    Text(dayNumber(for: day))
                                        .font(.caption2)
                                        .foregroundStyle(isToday ? AppColors.label : .secondary)
                                }
                                .frame(width: 40)
                                .overlay(alignment: .trailing) {
                                    if index < weekDays.count - 1 {
                                        Rectangle().fill(gridLine).frame(width: 1).frame(maxHeight: .infinity)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) { Rectangle().fill(gridLine).frame(height: 1) }
                        ForEach(actionsForThisWeek.sorted(by: { $0.name < $1.name }), id: \.persistentModelID) { action in
                            HStack(spacing: 0) {
                                HStack(spacing: 6) {
                                    CategoryColorDot(key: action.category?.colorKey, size: 8)
                                    Text(action.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                                .frame(width: 100, alignment: .leading)
                                .padding(.horizontal, 8)
                                .overlay(alignment: .trailing) { Rectangle().fill(gridLine).frame(width: 1).frame(maxHeight: .infinity) }
                                ForEach(Array(weekDays.enumerated()), id: \.element) { index, day in
                                    let isCompleted = isActionCompletedOnDay(action, day: day)
                                    Group {
                                        if isCompleted {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(CategoryColors.color(for: action.category?.colorKey))
                                        } else {
                                            Color.clear
                                        }
                                    }
                                    .frame(width: 40)
                                    .overlay(alignment: .trailing) {
                                        if index < weekDays.count - 1 {
                                            Rectangle().fill(gridLine).frame(width: 1).frame(maxHeight: .infinity)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                            .overlay(alignment: .bottom) { Rectangle().fill(gridLine).frame(height: 1) }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
    }

    private func categoryGrid(categoryProgresses: [CategoryProgress]) -> some View {
        SectionCardView(title: "🎯 카테고리별 달성률", accessory: { CategoryProgressInfoButton() }) {
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(categoryProgresses.prefix(8)) { progress in
                    categoryCard(progress: progress)
                }
            }
        }
    }

    private struct CategoryProgressInfoButton: View {
        @State private var showInfo = false
        var body: some View {
            Button { showInfo = true } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showInfo, attachmentAnchor: .point(.top)) {
                CategoryProgressInfoView()
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    private struct CategoryProgressInfoView: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("카테고리별 달성률 계산 방법")
                    .font(.headline)
                Text("액션마다 진행기간(시작일~오늘) 안에서 발생 대비 완료 비율(%)을 구한 뒤, 카테고리는 그 액션별 %의 평균으로 표시합니다. 액션 수가 많다고 유리하지 않습니다.")
                    .font(.subheadline)
                Text("• 요일 반복·누적 시간: 해당 기간에 스케줄된 날만 발생, 완료한 날만 성공\n• 주 N회: 해당 기간의 주 수 × N이 발생, 주마다 최대 N회까지 성공으로 인정\n• 액션별 진행기간(시작/종료일)이 다르면 각자 기간만큼만 집계 후, 카테고리는 액션별 %의 평균")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(width: 280)
        }
    }

    private func categoryCard(progress: CategoryProgress) -> some View {
        let color = CategoryColors.color(for: progress.category.colorKey)
        let progressValue = Double(min(100, max(0, progress.percentage))) / 100.0
        let size: CGFloat = 40
        return VStack(spacing: 8) {
            ZStack {
                // 빈색: 가장 연하게
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: size, height: size)
                // 채운색: 아래에서 위로 %만큼 (찐한 색)
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: size, height: size)
                    .mask(
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                                .frame(height: size * (1 - progressValue))
                            Rectangle()
                                .fill(Color.black)
                                .frame(height: size * progressValue)
                        }
                        .frame(height: size, alignment: .bottom)
                    )
                // % 글자: 가장 찐하게
                Text("\(progress.percentage)%")
                    .font(.caption.weight(.black))
                    .foregroundStyle(color)
            }
            Text(progress.category.name)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
