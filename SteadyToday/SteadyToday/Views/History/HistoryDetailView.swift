import SwiftUI
import SwiftData

/// 선택된 날짜의 하단 섹션: 오늘의 달성률, 이번 주 목표, 오늘의 도전, 이번 주의 꾸준함, 카테고리별 달성 현황
struct HistoryDetailView: View {
    @Binding var selectedDay: Date
    @Binding var monthAnchor: Date

    private let calendar = Calendar.steadyMondayCalendar

    @Query(sort: \ActionCheck.createdAt, order: .reverse) private var checks: [ActionCheck]
    @Query(sort: \TimeSession.createdAt, order: .reverse) private var timeSessions: [TimeSession]
    @Query(sort: \RoutineAction.todayOrder) private var actions: [RoutineAction]
    @Query(sort: \MandalartCategory.sortOrder) private var categories: [MandalartCategory]
    @Query(sort: \GratitudeEntry.day, order: .reverse) private var dailyLogEntries: [GratitudeEntry]

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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(AppColors.secondaryLabel.opacity(0.3))
                    .frame(height: 1)
                Text(detailTitle(selectedDay))
                    .font(.headline)
                    .foregroundStyle(AppColors.label)
                    .lineLimit(1)
                Rectangle()
                    .fill(AppColors.secondaryLabel.opacity(0.3))
                    .frame(height: 1)
            }
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
        let daily = dailyDetail
        VStack(alignment: .leading, spacing: 20) {
            if daily.progress != nil {
                actionListCard(title: "🏅 오늘의 달성률", actions: daily.actions, progress: daily.progress)
            }

            // if !weeklyCompletedActions.isEmpty {
            //     actionListCard(title: "이번 주 목표", actions: weeklyCompletedActions)
            // }

            // if !challengeCompletedActions.isEmpty {
            //     actionListCard(title: "오늘의 도전", actions: challengeCompletedActions)
            // }

            dailyLogSection()

            actionCheckTable()

            if !categoryProgresses.isEmpty {
                categoryGrid(categoryProgresses: categoryProgresses)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

    /// 선택한 날짜 00:00 (여러 계산에서 공통 사용)
    private var selectedDayStart: Date { selectedDay.startOfDay(calendar: calendar) }
    /// 오늘 00:00 (카테고리 달성률 등에서 사용)
    private var todayStart: Date { Date().startOfDay(calendar: calendar) }
    /// 선택한 날이 속한 주 구간
    private var selectedWeekInterval: DateInterval { selectedDay.weekInterval(calendar: calendar) }
    /// 해당 주의 요일 배열 (꾸준함 테이블에서 한 번만 계산)
    private var selectedWeekDays: [Date] { getWeekDays(for: selectedWeekInterval) }
    /// 해당 주의 액션별 체크 목록 (꾸준함 테이블)
    private var selectedWeekChecks: [RoutineAction: [ActionCheck]] { getWeekChecks(for: selectedWeekInterval) }
    /// 해당 주에 표시할 액션 목록 (selectedWeekDays 기반으로 한 번만 계산)
    private var actionsForSelectedWeek: [RoutineAction] {
        actions.filter { action in
            selectedWeekDays.contains { day in
                action.isActive(on: day, calendar: calendar) && (action.type == .weeklyN || action.isScheduled(on: day, calendar: calendar))
            }
        }
    }

    private struct CategoryProgress: Identifiable {
        let category: MandalartCategory
        let completed: Int
        let total: Int
        let percentage: Int
        var id: PersistentIdentifier { category.persistentModelID }
    }

    private struct ActionStatus: Identifiable {
        let name: String
        let colorKey: String?
        let isCompleted: Bool
        var id: String { name }
    }

    /// 선택한 날짜의 섹션용 데이터 (진행률 + 액션별 완료 상태를 한 번에 계산)
    private var dailyDetail: (progress: DailyProgress?, actions: [ActionStatus]) {
        let dayStart = selectedDayStart
        var actionsList: [ActionStatus] = []
        var completedCount = 0
        var targetCount = 0

        let dailyTargets = actions.filter { action in
            action.isActive(on: dayStart, calendar: calendar)
                && action.type == .weekdayRepeat
                && action.isScheduled(on: dayStart, calendar: calendar)
        }
        for action in dailyTargets {
            targetCount += 1
            let isCompleted = checks.contains { $0.day == dayStart && $0.action?.persistentModelID == action.persistentModelID }
            if isCompleted { completedCount += 1 }
            actionsList.append(ActionStatus(name: action.name, colorKey: action.category?.colorKey, isCompleted: isCompleted))
        }

        let timeTargets = actions.filter { action in
            action.isActive(on: dayStart, calendar: calendar)
                && action.type == .timeBased
                && action.isScheduled(on: dayStart, calendar: calendar)
        }
        for action in timeTargets {
            targetCount += 1
            let total = timeSessions
                .filter { $0.action?.persistentModelID == action.persistentModelID && $0.attributedDay == dayStart }
                .reduce(0) { $0 + $1.durationMinutes }
            let isCompleted = total >= action.timeTargetMinutes
            if isCompleted { completedCount += 1 }
            actionsList.append(ActionStatus(name: action.name, colorKey: action.category?.colorKey, isCompleted: isCompleted))
        }

        // 주 N회: 오늘 체크한 것만 리스트에 포함 (안 했으면 오늘 할 일이 아니었던 것)
        let weeklyOnDay = actions.filter { action in
            guard action.type == .weeklyN, action.isActive(on: dayStart, calendar: calendar) else { return false }
            return checks.contains { $0.action?.persistentModelID == action.persistentModelID && $0.day == dayStart }
        }
        for action in weeklyOnDay {
            targetCount += 1
            completedCount += 1
            actionsList.append(ActionStatus(name: action.name, colorKey: action.category?.colorKey, isCompleted: true))
        }

        let progress: DailyProgress? = targetCount > 0 ? DailyProgress(completed: completedCount, target: targetCount) : nil
        let sorted = actionsList.sorted {
            if $0.isCompleted != $1.isCompleted { return $0.isCompleted && !$1.isCompleted }
            return $0.name < $1.name
        }
        return (progress, sorted)
    }

    /// 카테고리별 달성률: 각 액션의 시작일(또는 올해 1월 1일) ~ 오늘까지 발생한 횟수 중 완료한 비율
    private func calculateCategoryProgresses(for day: Date) -> [CategoryProgress] {
        let defaultIntervalStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: todayStart), month: 1, day: 1))!
        return categories.map { category in
            var total = 0, completed = 0
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
            }
            let percentage = total > 0 ? Int((Double(completed) / Double(total) * 100.0).rounded()) : 0
            return CategoryProgress(category: category, completed: completed, total: total, percentage: percentage)
        }.filter { $0.total > 0 }
    }

    // MARK: - UI Components

    private func actionListCard(title: String, actions: [ActionStatus], progress: DailyProgress? = nil) -> some View {
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
                                Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.title3)
                                    .foregroundStyle(action.isCompleted ? CategoryColors.color(for: action.colorKey) : .secondary)
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
                Text("각 액션의 시작일(미설정 시 올해 1월 1일) ~ 오늘까지, 발생한 횟수 중 완료한 비율을 카테고리별로 합산합니다.")
                    .font(.subheadline)
                Text("• 요일 반복·누적 시간: 해당 기간에 스케줄된 날만 발생으로 치고, 완료한 날만 성공\n• 주 N회: 해당 기간의 주 수 × N이 발생, 주마다 최대 N회까지 성공으로 인정\n• 액션별 진행기간(시작/종료일)이 다르면 각자 기간만큼만 집계됩니다.")
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
    private func dailyLogSection() -> some View {
        if let entry = selectedDayDailyLogEntry {
            SectionCardView(title: "📸 오늘의 기록") {
                VStack(alignment: .leading, spacing: 12) {
                    if let text = entry.text, !text.isEmpty {
                        Text(text)
                            .font(.body)
                            .foregroundStyle(AppColors.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    if let imageFileName = entry.imageURL,
                       let url = imageURL(from: imageFileName),
                       let imageData = try? Data(contentsOf: url),
                       let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, -16)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
    
    private func imageURL(from fileName: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(fileName)
    }
    
    /// 선택한 날짜의 오늘의 기록 엔트리(텍스트 또는 이미지가 있을 때만)
    private var selectedDayDailyLogEntry: GratitudeEntry? {
        let entry = dailyLogEntries.first { $0.day == selectedDayStart }
        guard let entry = entry else { return nil }
        guard (entry.text != nil && !entry.text!.isEmpty) || entry.imageURL != nil else { return nil }
        return entry
    }

    @ViewBuilder
    private func actionCheckTable() -> some View {
        if !actionsForSelectedWeek.isEmpty {
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
                            ForEach(Array(selectedWeekDays.enumerated()), id: \.element) { index, day in
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
                                    if index < selectedWeekDays.count - 1 {
                                        Rectangle().fill(gridLine).frame(width: 1).frame(maxHeight: .infinity)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) { Rectangle().fill(gridLine).frame(height: 1) }
                        ForEach(actionsForSelectedWeek.sorted(by: { $0.name < $1.name }), id: \.persistentModelID) { action in
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
                                ForEach(Array(selectedWeekDays.enumerated()), id: \.element) { index, day in
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
                                        if index < selectedWeekDays.count - 1 {
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

    /// 해당 날짜에 액션이 완료된지. (요일반복/주N회/타임기반 모두 완료 시 ActionCheck 생성하므로 체크 테이블만 보면 됨)
    private func isActionCompletedOnDay(_ action: RoutineAction, day: Date) -> Bool {
        let dayStart = day.startOfDay(calendar: calendar)
        return checks.contains { $0.action?.persistentModelID == action.persistentModelID && $0.day == dayStart }
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
