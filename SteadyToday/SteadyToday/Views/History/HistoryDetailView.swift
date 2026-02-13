import SwiftUI
import SwiftData

/// 선택된 날짜의 하단 섹션: 그날의 달성률(오늘의 달성률), 감사일기. 스와이프 시 날짜 변경.
struct HistoryDetailView: View {
    @Binding var selectedDay: Date
    @Binding var monthAnchor: Date

    private let calendar = Calendar.steadyMondayCalendar

    @Query(sort: \ActionCheck.createdAt, order: .reverse) private var checks: [ActionCheck]
    @Query(sort: \TimeSession.createdAt, order: .reverse) private var timeSessions: [TimeSession]
    @Query(sort: \RoutineAction.todayOrder) private var actions: [RoutineAction]
    @Query(sort: \GratitudeEntry.day, order: .reverse) private var dailyLogEntries: [GratitudeEntry]

    var body: some View {
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

            summaryView()
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
    private func summaryView() -> some View {
        let daily = dailyDetail
        VStack(alignment: .leading, spacing: 20) {
            if daily.progress != nil {
                actionListCard(title: "🏅 오늘의 달성률", actions: daily.actions, progress: daily.progress)
            }
            dailyLogSection()
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

}
