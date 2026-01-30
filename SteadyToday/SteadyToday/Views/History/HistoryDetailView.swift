import SwiftUI
import SwiftData

/// 선택된 날짜의 하단 섹션: 오늘의 액션, 이번 주 목표, 오늘의 도전, 이번 주의 꾸준함, 카테고리별 달성 현황
struct HistoryDetailView: View {
    @Binding var selectedDay: Date
    @Binding var monthAnchor: Date

    private let calendar = Calendar.steadyMondayCalendar

    @Query(sort: \ActionCheck.createdAt, order: .reverse) private var checks: [ActionCheck]
    @Query(sort: \TimeSession.createdAt, order: .reverse) private var timeSessions: [TimeSession]
    @Query(sort: \RoutineAction.todayOrder) private var actions: [RoutineAction]
    @Query(sort: \MandalartCategory.sortOrder) private var categories: [MandalartCategory]

    init(selectedDay: Binding<Date>, monthAnchor: Binding<Date>) {
        _selectedDay = selectedDay
        _monthAnchor = monthAnchor
        let year = Calendar.steadyMondayCalendar.component(.year, from: Date())
        _categories = Query(
            filter: #Predicate<MandalartCategory> { $0.planYear?.year == year },
            sort: [SortDescriptor(\.sortOrder, order: .forward)]
        )
    }

    var body: some View {
        let categoryProgresses = calculateCategoryProgresses(for: selectedDay)
        VStack(alignment: .leading, spacing: 20) {
            Text(detailTitle(selectedDay))
                .font(.headline)
                .padding(.horizontal, 16)

            summaryView(categoryProgresses: categoryProgresses)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .gesture(detailSwipeGesture)
        .padding(.top, 10)
        .padding(.bottom, 24)
    }

    // MARK: - Helpers

    private func detailTitle(_ day: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: day)
    }

    @ViewBuilder
    private func summaryView(categoryProgresses: [CategoryProgress]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 12) {
                let dailyProgress = calculateDailyProgress(for: selectedDay)
                let dailyCompletedActions = getDailyCompletedActions(for: selectedDay)
                let weeklyCompletedActions = getWeeklyCompletedActions(for: selectedDay)
                let challengeCompletedActions = getChallengeCompletedActions(for: selectedDay)

                if dailyProgress != nil {
                    actionListCard(title: "오늘의 액션", actions: dailyCompletedActions, progress: dailyProgress)
                }

                // if !weeklyCompletedActions.isEmpty {
                //     actionListCard(title: "이번 주 목표", actions: weeklyCompletedActions)
                // }

                // if !challengeCompletedActions.isEmpty {
                //     actionListCard(title: "오늘의 도전", actions: challengeCompletedActions)
                // }
            }
            .padding(.horizontal, 16)

            actionCheckTable()
                .padding(.horizontal, 16)

            if !categoryProgresses.isEmpty {
                categoryGrid(categoryProgresses: categoryProgresses)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var detailSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) + 20 else { return }
                if value.translation.width < -40 {
                    changeSelectedDay(deltaDays: 1)
                } else if value.translation.width > 40 {
                    changeSelectedDay(deltaDays: -1)
                }
            }
    }

    private func changeSelectedDay(deltaDays: Int) {
        guard let next = calendar.date(byAdding: .day, value: deltaDays, to: selectedDay) else { return }
        let nextDay = next.startOfDay(calendar: calendar)
        selectedDay = nextDay
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor))!
        let nextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: nextDay))!
        if currentMonth != nextMonth {
            monthAnchor = nextDay
        }
    }

    // MARK: - Data & Progress

    private struct TypeProgress {
        let completed: Int
        let target: Int
        let percentage: Int
    }

    private struct CategoryProgress: Identifiable {
        let category: MandalartCategory
        let completed: Int
        let total: Int
        let percentage: Int
        var id: PersistentIdentifier { category.persistentModelID }
    }

    private struct CompletedAction: Identifiable {
        let name: String
        let colorKey: String?
        var id: String { name }
    }

    private func calculateDailyProgress(for day: Date) -> TypeProgress? {
        let dayStart = day.startOfDay(calendar: calendar)
        let dailyTargets = actions.filter { action in
            action.isActive(on: dayStart, calendar: calendar) && action.type == .weekdayRepeat && action.isScheduled(on: dayStart, calendar: calendar)
        }
        let dailyCompleted = checks.filter { check in
            guard check.day == dayStart else { return false }
            guard let action = check.action else { return false }
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
        let percentage = Int((Double(totalCompleted) / Double(totalTarget) * 100.0).rounded())
        return TypeProgress(completed: totalCompleted, target: totalTarget, percentage: percentage)
    }

    private func getDailyCompletedActions(for day: Date) -> [CompletedAction] {
        let dayStart = day.startOfDay(calendar: calendar)
        var result: [CompletedAction] = []
        let dailyChecks = checks.filter { check in
            guard check.day == dayStart, let action = check.action else { return false }
            return action.type == .weekdayRepeat && action.isActive(on: dayStart, calendar: calendar)
        }
        result.append(contentsOf: dailyChecks.compactMap { check in
            guard let action = check.action else { return nil }
            return CompletedAction(name: action.name, colorKey: action.category?.colorKey)
        })
        for action in actions where action.isActive(on: dayStart, calendar: calendar) && action.type == .timeBased && action.isScheduled(on: dayStart, calendar: calendar) {
            let total = timeSessions
                .filter { $0.action?.persistentModelID == action.persistentModelID }
                .filter { $0.attributedDay == dayStart }
                .reduce(0) { $0 + $1.durationMinutes }
            if total >= action.timeTargetMinutes {
                result.append(CompletedAction(name: action.name, colorKey: action.category?.colorKey))
            }
        }
        for action in actions where action.type == .weeklyN && action.isActive(on: dayStart, calendar: calendar) {
            if checks.contains(where: { $0.action?.persistentModelID == action.persistentModelID && $0.day == dayStart }) {
                result.append(CompletedAction(name: action.name, colorKey: action.category?.colorKey))
            }
        }
        return result
    }

    private func getChallengeCompletedActions(for day: Date) -> [CompletedAction] {
        let dayStart = day.startOfDay(calendar: calendar)
        let timeTargets = actions.filter { $0.isActive(on: dayStart, calendar: calendar) && $0.type == .timeBased && $0.isScheduled(on: dayStart, calendar: calendar) }
        var completedActions: [CompletedAction] = []
        for action in timeTargets {
            let total = timeSessions
                .filter { $0.action?.persistentModelID == action.persistentModelID }
                .filter { $0.attributedDay == dayStart }
                .reduce(0) { $0 + $1.durationMinutes }
            if total >= action.timeTargetMinutes {
                completedActions.append(CompletedAction(name: action.name, colorKey: action.category?.colorKey))
            }
        }
        return completedActions
    }

    private func getWeeklyCompletedActions(for day: Date) -> [CompletedAction] {
        let dayStart = day.startOfDay(calendar: calendar)
        let thisWeek = day.weekInterval(calendar: calendar)
        let weeklyTargets = actions.filter { $0.isActive(on: dayStart, calendar: calendar) && $0.type == .weeklyN }
        var completedActions: [CompletedAction] = []
        for action in weeklyTargets {
            let actionChecks = checks.filter {
                guard $0.action?.persistentModelID == action.persistentModelID else { return false }
                return $0.day >= thisWeek.start && $0.day < thisWeek.end
            }
            if !actionChecks.isEmpty {
                completedActions.append(CompletedAction(name: action.name, colorKey: action.category?.colorKey))
            }
        }
        return completedActions
    }

    private func calculateCategoryProgresses(for day: Date) -> [CategoryProgress] {
        let (monthStart, monthEnd) = day.monthInterval(calendar: calendar)
        let todayStart = Date().startOfDay(calendar: calendar)
        return categories.map { category in
            var total = 0, completed = 0
            for action in category.actions {
                guard action.isActive else { continue }
                switch action.type {
                case .weekdayRepeat:
                    var d = monthStart
                    while d < monthEnd {
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
                    var d = monthStart
                    while d < monthEnd {
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
                    var weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: monthStart))!
                    var weeksInMonth = 0
                    while weekStart < monthEnd {
                        weeksInMonth += 1
                        weekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                    }
                    total += weeksInMonth * action.weeklyTargetN
                    weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: monthStart))!
                    while weekStart < monthEnd {
                        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
                        if weekStart <= todayStart {
                            let weekChecks = checks.filter { check in
                                guard check.action?.persistentModelID == action.persistentModelID else { return false }
                                let ds = check.day.startOfDay(calendar: calendar)
                                return ds >= weekStart && ds < weekEnd
                            }
                            completed += min(action.weeklyTargetN, weekChecks.count)
                        }
                        weekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                    }
                }
            }
            let percentage = total > 0 ? Int((Double(completed) / Double(total) * 100.0).rounded()) : 0
            return CategoryProgress(category: category, completed: completed, total: total, percentage: percentage)
        }.filter { $0.total > 0 }
    }

    // MARK: - UI Components

    private func actionListCard(title: String, actions: [CompletedAction], progress: TypeProgress? = nil) -> some View {
        SectionCardView(title: title) {
            VStack(alignment: .leading, spacing: 12) {
                if let progress = progress {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("\(progress.completed) / \(progress.target) 완료")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.secondaryLabel)
                            Spacer()
                            Text("\(progress.percentage)%")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppColors.label)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppColors.label.opacity(0.12))
                                    .frame(height: 12)
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(AppColors.label)
                                    .frame(width: geometry.size.width * CGFloat(progress.percentage) / 100.0, height: 12)
                            }
                        }
                        .frame(height: 12)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.label.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if !actions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(actions) { action in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.title3)
                                    .foregroundStyle(CategoryColors.color(for: action.colorKey))
                                Text(action.name)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.label)
                            }
                        }
                    }
                    .padding(.top, progress != nil ? 4 : 0)
                }
            }
        }
    }

    private func categoryGrid(categoryProgresses: [CategoryProgress]) -> some View {
        SectionCardView(title: "이달의 카테고리 달성 현황", accessory: { CategoryProgressInfoButton() }) {
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
                Text("선택한 날짜가 속한 달 기준으로, 달 시작~오늘까지 성공한 횟수 / 그 달에 발생하는 액션 수 비율입니다.")
                    .font(.subheadline)
                Text("• 요일 반복·누적 시간: 그 달에 반복 요일에 해당하는 일수만큼 발생, 체크(또는 목표 시간 달성)한 날만 성공\n• 주 N회: 그 달에 걸친 주 수 × N이 발생, 주마다 최대 N회까지 성공으로 인정")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(width: 280)
        }
    }

    private func categoryCard(progress: CategoryProgress) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(CategoryColors.color(for: progress.category.colorKey))
                    .frame(width: 40, height: 40)
                    .opacity(0.2)
                Circle()
                    .stroke(CategoryColors.color(for: progress.category.colorKey), lineWidth: 2)
                    .frame(width: 40, height: 40)
                Text("\(progress.percentage)%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(CategoryColors.color(for: progress.category.colorKey))
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

    @ViewBuilder
    private func actionCheckTable() -> some View {
        let weekInterval = selectedDay.weekInterval(calendar: calendar)
        let weekDays = getWeekDays(for: weekInterval)
        let weekChecks = getWeekChecks(for: weekInterval)
        let actionsForWeek = getActionsForWeek(weekInterval: weekInterval)
        if !actionsForWeek.isEmpty {
            let gridLine = AppColors.gridLine
            SectionCardView(title: "이번 주의 꾸준함") {
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
                                VStack(spacing: 4) {
                                    Text(dayLabel(for: day))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(day == selectedDay ? AppColors.label : .secondary)
                                    Text(dayNumber(for: day))
                                        .font(.caption2)
                                        .foregroundStyle(day == selectedDay ? AppColors.label : .secondary)
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
                        ForEach(actionsForWeek.sorted(by: { $0.name < $1.name }), id: \.persistentModelID) { action in
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
                                    let dayChecks = weekChecks[action] ?? []
                                    let isChecked = dayChecks.contains { $0.day == day.startOfDay(calendar: calendar) }
                                    Group {
                                        if isChecked {
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

    private func getWeekDays(for weekInterval: DateInterval) -> [Date] {
        var days: [Date] = []
        var currentDate = weekInterval.start
        while currentDate < weekInterval.end {
            days.append(currentDate.startOfDay(calendar: calendar))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        return days
    }

    private func getActionsForWeek(weekInterval: DateInterval) -> [RoutineAction] {
        let weekDays = getWeekDays(for: weekInterval)
        return actions.filter { action in
            weekDays.contains { day in
                action.isActive(on: day, calendar: calendar) && (action.type == .weeklyN || action.isScheduled(on: day, calendar: calendar))
            }
        }
    }

    private func getWeekChecks(for weekInterval: DateInterval) -> [RoutineAction: [ActionCheck]] {
        let weekChecks = checks.filter { check in
            let checkDay = check.day.startOfDay(calendar: calendar)
            return checkDay >= weekInterval.start && checkDay < weekInterval.end
        }
        var result: [PersistentIdentifier: (action: RoutineAction, checks: [ActionCheck])] = [:]
        for check in weekChecks {
            guard let action = check.action else { continue }
            let actionID = action.persistentModelID
            if result[actionID] == nil { result[actionID] = (action: action, checks: []) }
            result[actionID]?.checks.append(check)
        }
        var finalResult: [RoutineAction: [ActionCheck]] = [:]
        for (_, value) in result { finalResult[value.action] = value.checks }
        return finalResult
    }

    private func dayLabel(for day: Date) -> String {
        let weekday = calendar.component(.weekday, from: day)
        let labels = ["일", "월", "화", "수", "목", "금", "토"]
        return labels[(weekday - 1) % 7]
    }

    private func dayNumber(for day: Date) -> String {
        "\(calendar.component(.day, from: day))"
    }
}
