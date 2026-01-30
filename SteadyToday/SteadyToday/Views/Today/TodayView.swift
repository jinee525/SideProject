import SwiftUI
import SwiftData
import Combine

// MARK: - Time Action Card Item

private enum TimeActionCardItem {
    case completed(session: TimeSession, action: RoutineAction)
    case active(action: RoutineAction, runningSession: TimeSession?)
    
    var id: String {
        switch self {
        case .completed(let session, _):
            return "completed-\(session.persistentModelID.hashValue)"
        case .active(let action, _):
            return "active-\(action.persistentModelID.hashValue)"
        }
    }
}

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext

    private let calendar = Calendar.steadyMondayCalendar
    private var today: Date { Date().startOfDay(calendar: calendar) }
    private var thisWeek: DateInterval { Date().weekInterval(calendar: calendar) }
    private var titleEmoji: String { emojiForToday(today) }
    private var titleText: String { "\(formattedTodayTitle(today)) \(titleEmoji)" }

    @Query(sort: \RoutineAction.todayOrder) private var allActions: [RoutineAction]
    @Query(sort: \ActionCheck.createdAt, order: .reverse) private var allChecks: [ActionCheck]
    @Query(sort: \TimeSession.createdAt, order: .reverse) private var timeSessions: [TimeSession]
    @Query(sort: \GratitudeEntry.day, order: .reverse) private var gratitudeEntries: [GratitudeEntry]
    
    @State private var showingGratitudeEditor = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    normalSections
                    // 여유 공간 추가
                    Section {
                        Spacer()
                            .frame(height: 80)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(6)
                .scrollContentBackground(.hidden)
                .navigationTitle(titleText)
                .toolbar {
                    EmptyView()
                }
                .onAppear {
                    bootstrapIfNeeded()
                }
                
                // 감사일기 버튼 (우측 하단)
                Button {
                    showingGratitudeEditor = true
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(Color.pink)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .sheet(isPresented: $showingGratitudeEditor) {
                GratitudeEditModal(day: today)
            }
        }
    }
    
    @ViewBuilder
    private var normalSections: some View {
        if !timeActions.isEmpty {
            timeActionSection
        }
        if !weeklyActions.isEmpty {
            weeklySection
        }
        
        dailySection
    }
    
    private var weeklySection: some View {
        Section("이번 주 목표") {
            ForEach(weeklyActions) { action in
                ActionRow(
                    colorKey: action.category?.colorKey,
                    title: action.name,
                    subtitle: subtitle(for: action),
                    isChecked: isCheckedToday(action),
                    isEnabled: true,
                    action: action
                ) {
                    toggleCheck(action)
                }
            }
        }
    }
    
    private var timeActionSection: some View {
        Section {
            SectionCardView(title: "오늘의 도전") {
                TimeActionCardsSection(
                    cardItems: timeActionCardItems,
                    today: today,
                    isTimeGoalMetToday: { isTimeGoalMetToday($0) },
                    totalMinutesForAction: { action, day in totalMinutes(for: action, on: day) },
                    onStartTimer: { startTimer(for: $0) },
                    onStopTimer: { stopTimer(for: $0) }
                )
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
    
    private var dailySection: some View {
        Section("오늘의 액션") {
            ForEach(dailyTodayActions) { action in
                ActionRow(
                    colorKey: action.category?.colorKey,
                    title: action.name,
                    subtitle: subtitle(for: action),
                    isChecked: isCheckedToday(action),
                    isEnabled: true,
                    action: action
                ) {
                    toggleCheck(action)
                }
            }
        }
    }

    private var timeActionCardItems: [TimeActionCardItem] {
        var items: [TimeActionCardItem] = []
        
        for action in timeActions {
            // 진행 중인 세션이 있는지 확인
            let runningSession = ongoingTimeSession(for: action)
            
            // 진행 중인 세션이 있으면 진행 중 카드만 표시
            if runningSession != nil {
                items.append(.active(action: action, runningSession: runningSession))
            } else {
                // 오늘 시작해서 완료된 세션이 있는지 확인 (시작 날짜가 오늘인 완료된 세션)
                let completedSessionsToday = timeSessions.filter {
                    $0.action?.persistentModelID == action.persistentModelID &&
                    !$0.isOngoing &&
                    $0.attributedDay == today
                }
                
                if let firstCompletedSession = completedSessionsToday.first {
                    // 오늘 시작해서 완료된 세션이 있으면 완료 카드만 표시
                    items.append(.completed(session: firstCompletedSession, action: action))
                } else {
                    // 오늘 시작해서 완료된 세션이 없으면 시작 가능 카드 표시
                    items.append(.active(action: action, runningSession: nil))
                }
            }
        }
        
        return items
    }

    private var activeActions: [RoutineAction] {
        allActions.filter { $0.isActive(on: today, calendar: calendar) }
    }

    private var weeklyActions: [RoutineAction] {
        activeActions.filter { $0.type == .weeklyN }
    }

    private var timeActions: [RoutineAction] {
        activeActions.filter { action in
            guard action.type == .timeBased else { return false }
            // 진행 중인 타이머가 있으면 요일 필터링 무시하고 항상 표시
            if let session = ongoingTimeSession(for: action), session.isOngoing {
                return true
            }
            // 그 외에는 오늘 요일에 해당하는 액션만 표시
            return action.isScheduled(on: today, calendar: calendar)
        }
    }

    private var dailyTodayActions: [RoutineAction] {
        activeActions.filter { $0.type == .weekdayRepeat && $0.isScheduled(on: today, calendar: calendar) }
    }

    private func isEnabledToday(_ action: RoutineAction) -> Bool {
        if action.type == .weeklyN { return true }
        return action.isScheduled(on: today, calendar: calendar)
    }

    private func subtitle(for action: RoutineAction) -> String {
        switch action.type {
        case .weekdayRepeat:
            return ""
        case .weeklyN:
            let count = weeklyCount(action)
            return "주 \(action.weeklyTargetN)회 (\(count)/\(action.weeklyTargetN))"
        case .timeBased:
            return timeSubtitle(for: action)
        }
    }

    private func isCheckedToday(_ action: RoutineAction) -> Bool {
        allChecks.contains { $0.action?.persistentModelID == action.persistentModelID && $0.day == today }
    }

    private func weeklyCount(_ action: RoutineAction) -> Int {
        guard action.type == .weeklyN else { return 0 }
        return allChecks.filter {
            guard $0.action?.persistentModelID == action.persistentModelID else { return false }
            return $0.day >= thisWeek.start && $0.day < thisWeek.end
        }.count
    }

    private func toggleCheck(_ action: RoutineAction) {
        guard isEnabledToday(action) else { return }
        withAnimation {
            if let existing = allChecks.first(where: { $0.action?.persistentModelID == action.persistentModelID && $0.day == today }) {
                modelContext.delete(existing)
            } else {
                let check = ActionCheck(day: today, createdAt: .now, action: action)
                modelContext.insert(check)
            }
        }
    }

    // MARK: - Bootstrap

    private func bootstrapIfNeeded() {
        let year = calendar.component(.year, from: Date())
        let existing = (try? modelContext.fetch(FetchDescriptor<PlanYear>(predicate: #Predicate { $0.year == year })))?.first
        if existing == nil {
            modelContext.insert(PlanYear(year: year, goalTitle: ""))
        }
    }

    // MARK: - Time-based actions

    private func timeSubtitle(for action: RoutineAction) -> String {
        let total = totalMinutes(for: action, on: today)
        let formatted = formatMinutes(total)
        let target = formatMinutes(action.timeTargetMinutes)
        return "\(formatted) / \(target)"
    }

    private func totalMinutes(for action: RoutineAction, on day: Date) -> Int {
        let dayStart = day.startOfDay(calendar: calendar)
        return timeSessions
            .filter { $0.action?.persistentModelID == action.persistentModelID }
            .filter { $0.attributedDay == dayStart }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private func isTimeGoalMetToday(_ action: RoutineAction) -> Bool {
        return totalMinutes(for: action, on: today) >= action.timeTargetMinutes
    }

    private func ongoingTimeSession(for action: RoutineAction) -> TimeSession? {
        timeSessions.first { $0.action?.persistentModelID == action.persistentModelID && $0.isOngoing }
    }

    private func startTimer(for action: RoutineAction) {
        guard ongoingTimeSession(for: action) == nil else { return }
        let attributedDay = Date().startOfDay(calendar: calendar)
        let session = TimeSession(attributedDay: attributedDay, durationMinutes: 0, isManual: false, startAt: Date(), endAt: nil, action: action)
        modelContext.insert(session)
    }

    private func stopTimer(for action: RoutineAction) {
        guard let session = ongoingTimeSession(for: action) else { return }
        let end = Date()
        session.endAt = end
        let minutes = max(0, Int(end.timeIntervalSince(session.startAt ?? end) / 60))
        session.durationMinutes = minutes
        // attributedDay는 시작 날짜로 유지 (완료율 집계는 시작 날짜 기준)
        // session.attributedDay는 startTimer에서 이미 시작 날짜로 설정되어 있음

        // 타임 기반 액션 목표 달성 시 이번 주 꾸준함 테이블용 ActionCheck 생성 (TimeSession만으로는 테이블에 안 나오므로)
        let dayStart = session.attributedDay ?? Date().startOfDay(calendar: calendar)
        if totalMinutes(for: action, on: dayStart) >= action.timeTargetMinutes {
            if !allChecks.contains(where: { $0.action?.persistentModelID == action.persistentModelID && $0.day == dayStart }) {
                modelContext.insert(ActionCheck(day: dayStart, createdAt: .now, action: action))
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m)분" }
        if m == 0 { return "\(h)시간" }
        return "\(h)시간 \(m)분"
    }

    // MARK: - Title

    private func formattedTodayTitle(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 EEEE"
        return f.string(from: date)
    }

    private func emojiForToday(_ date: Date) -> String {
        let emojis = ["🙂", "😺", "🌿", "🍀", "🔥", "🌟", "☀️", "🌙", "🏃", "📌", "🧠", "🫶"]
        let dayNumber = Int(date.startOfDay(calendar: calendar).timeIntervalSince1970 / 86_400)
        let idx = abs(dayNumber) % emojis.count
        return emojis[idx]
    }
}

// MARK: - Time Action Card

private struct TimeActionCard: View {
    let action: RoutineAction
    let colorKey: String?
    let isCompleted: Bool
    let totalMinutes: Int
    let isRunning: Bool
    let runningStartAt: Date?
    let onStart: () -> Void
    let onStop: () -> Void
    
    private var cardWidth: CGFloat { 200 }
    private var cardHeight: CGFloat { cardWidth * 0.75 } // 4:3 비율
    
    private var isSuccess: Bool {
        totalMinutes >= action.timeTargetMinutes
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 상단: 액션명 & 색상
            HStack {
                CategoryColorDot(key: colorKey, size: 10)
                Text(action.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
            }
            
            // 중앙: 시간 표시
            cardTimeDisplay
            
            // 하단: 버튼 또는 완료 표시
            cardBottom
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(width: cardWidth, height: cardHeight)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    @ViewBuilder
    private var cardTimeDisplay: some View {
        if isCompleted {
            // 완료된 경우: 완료 시간과 목표 표시
            VStack(spacing: 4) {
                Text(formatTime(totalMinutes))
                    .font(.system(.title2, design: .monospaced))
                    .foregroundStyle(AppColors.label)
                Text(formatTime(action.timeTargetMinutes))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else if isRunning, let startAt = runningStartAt {
            // 진행 중: 실시간 타이머와 목표 표시
            VStack(spacing: 4) {
                LiveTimerView(startAt: startAt)
                Text(formatTime(action.timeTargetMinutes))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            // 시작 전: 00:00:00과 목표 표시
            VStack(spacing: 4) {
                Text("00:00:00")
                    .font(.system(.title2, design: .monospaced))
                    .foregroundStyle(AppColors.label)
                Text(formatTime(action.timeTargetMinutes))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var cardBottom: some View {
        if isCompleted {
            // 완료된 경우: 성공/완료 텍스트만
            let categoryColor = CategoryColors.color(for: colorKey)
            Text(isSuccess ? "성공" : "완료")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSuccess ? categoryColor : .secondary)
        } else if isRunning {
            // 진행 중: 종료 버튼
            Button("종료") {
                onStop()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.label)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(AppColors.label.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            // 시작 전: 시작 버튼
            Button("시작") {
                onStart()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.label)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(AppColors.label.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    private var cardBackground: some View {
        let categoryColor = CategoryColors.color(for: colorKey)
        return RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(categoryColor.opacity(0.2))
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d:00", hours, mins)
    }
}

// 실시간 타이머 표시
private struct LiveTimerView: View {
    let startAt: Date
    @State private var elapsed: TimeInterval = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(formattedTime)
            .font(.system(.title2, design: .monospaced))
            .foregroundStyle(AppColors.label)
            .onReceive(timer) { _ in
                elapsed = Date().timeIntervalSince(startAt)
            }
            .onAppear {
                elapsed = Date().timeIntervalSince(startAt)
            }
    }
    
    private var formattedTime: String {
        let totalSeconds = Int(elapsed)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Time Action Cards Section

private struct TimeActionCardsSection: View {
    let cardItems: [TimeActionCardItem]
    let today: Date
    let isTimeGoalMetToday: (RoutineAction) -> Bool
    let totalMinutesForAction: (RoutineAction, Date) -> Int
    let onStartTimer: (RoutineAction) -> Void
    let onStopTimer: (RoutineAction) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(cardItems, id: \.id) { item in
                    cardView(for: item)
                }
            }
        }
    }
    
    @ViewBuilder
    private func cardView(for item: TimeActionCardItem) -> some View {
        switch item {
        case .completed(let session, let action):
            let day = session.attributedDay ?? Date()
            let total = totalMinutesForAction(action, day)
            TimeActionCard(
                action: action,
                colorKey: action.category?.colorKey,
                isCompleted: true,
                totalMinutes: total,
                isRunning: false,
                runningStartAt: nil,
                onStart: { },
                onStop: { }
            )
        case .active(let action, let runningSession):
            let currentTotal = totalMinutesForAction(action, today)
            TimeActionCard(
                action: action,
                colorKey: action.category?.colorKey,
                isCompleted: false,
                totalMinutes: currentTotal,
                isRunning: runningSession != nil,
                runningStartAt: runningSession?.startAt,
                onStart: { onStartTimer(action) },
                onStop: { onStopTimer(action) }
            )
        }
    }
}


private struct ActionRow: View {
    let colorKey: String?
    let title: String
    let subtitle: String
    let isChecked: Bool
    let isEnabled: Bool
    let action: RoutineAction
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CategoryColorDot(key: colorKey, size: 12)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onToggle) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isChecked ? CategoryColors.color(for: colorKey) : Color.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.35)
        }
        .frame(minHeight: 52) // 최소 높이 고정
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }
}

// MARK: - Common Time Picker Component

struct WheelTimePicker: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    
    var body: some View {
        HStack(spacing: 0) {
            // 시간 Picker
            VStack(spacing: 4) {
                Text("시간")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("시간", selection: $hours) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text("\(hour)")
                            .tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }
            .frame(maxWidth: .infinity)

            Text(":")
                .font(.title2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            // 분 Picker
            VStack(spacing: 4) {
                Text("분")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("분", selection: $minutes) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text(String(format: "%02d", minute))
                            .tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            PlanYear.self,
            MandalartCategory.self,
            RoutineAction.self,
            ActionCheck.self,
            TimeSession.self,
        ], inMemory: true)
}
