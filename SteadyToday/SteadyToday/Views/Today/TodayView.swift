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
    private var selectedWeek: DateInterval { selectedDay.weekInterval(calendar: calendar) }
    private var titleEmoji: String { emojiForToday(selectedDay) }
    private var titleText: String { formattedTodayTitle(selectedDay) }
    private var isViewingToday: Bool { calendar.isDate(selectedDay, inSameDayAs: today) }

    @Query(sort: \RoutineAction.todayOrder) private var allActions: [RoutineAction]
    @Query(sort: \ActionCheck.createdAt, order: .reverse) private var allChecks: [ActionCheck]
    @Query(sort: \TimeSession.createdAt, order: .reverse) private var timeSessions: [TimeSession]
    @Query(sort: \GratitudeEntry.day, order: .reverse) private var dailyLogEntries: [GratitudeEntry]
    
    @State private var selectedDay: Date = Date().startOfDay(calendar: .steadyMondayCalendar)
    @State private var showingDailyLogEditor = false

    var body: some View {
        MainTabLayout(
            title: titleText,
            showLeftButton: true,
            showRightButton: !isViewingToday,
            onLeftTap: {
                selectedDay = calendar.date(byAdding: .day, value: -1, to: selectedDay) ?? selectedDay
            },
            onRightTap: {
                selectedDay = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
            }
        ) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 20) {
                        normalSections
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 80)
                }
                .scrollContentBackground(.hidden)
                .onAppear {
                    bootstrapIfNeeded()
                }
                
                VStack(alignment: .trailing, spacing: 12) {
                    if !isViewingToday {
                        Button {
                            selectedDay = today
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle()
                                        .fill(Color(.systemGray).opacity(0.5))
                                )
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    // 오늘의 기록 버튼 (우측 하단)
                    Button {
                        showingDailyLogEditor = true
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
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .sheet(isPresented: $showingDailyLogEditor) {
                DailyLogEditModal(day: selectedDay)
            }
        }
    }
    
    @ViewBuilder
    private var normalSections: some View {
        if !timeActionCardItems.isEmpty {
            timeActionSection
        }
        if !weeklyActions.isEmpty {
            weeklySection
        }
        if !dailyTodayActions.isEmpty {
            dailySection
        }
        if dailyLogEntry != nil {
            dailyLogSection
        }
    }

    
    private var weeklySection: some View {
        SectionCardView(title: "⭐️ 이번 주 목표") {
            VStack(spacing: 4) {
                ForEach(weeklyActions) { action in
                    ActionRow(
                        colorKey: action.category?.colorKey,
                        title: action.name,
                        subtitle: subtitle(for: action),
                        isChecked: isCheckedOnSelectedDay(action),
                        isEnabled: true,
                        action: action
                    ) {
                        toggleCheck(action)
                    }
                }
            }
        }
    }
    
    private var timeActionSection: some View {
        SectionCardView(title: "⏰ 오늘의 도전") {
            TimeActionCardsSection(
                cardItems: timeActionCardItems,
                today: selectedDay,
                isTimeGoalMetToday: { isTimeGoalMetToday($0) },
                totalMinutesForAction: { action, day in totalMinutes(for: action, on: day) },
                onStartTimer: { startTimer(for: $0) },
                onStopTimer: { stopTimer(for: $0) }
            )
        }
    }
    
    private var dailySection: some View {
        SectionCardView(title: "⛳️ 오늘의 액션") {
            VStack(spacing: 4) {
                ForEach(dailyTodayActions) { action in
                    ActionRow(
                        colorKey: action.category?.colorKey,
                        title: action.name,
                        subtitle: subtitle(for: action),
                        isChecked: isCheckedOnSelectedDay(action),
                        isEnabled: true,
                        action: action
                    ) {
                        toggleCheck(action)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var dailyLogSection: some View {
        if let entry = dailyLogEntry {
            SectionCardView(title: "📸 오늘의 기록") {
                VStack(alignment: .leading, spacing: 12) {
                    if let text = entry.text, !text.isEmpty {
                        Text(text)
                            .font(.body)
                            .foregroundStyle(AppColors.label)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let imageFileName = entry.imageURL,
                       let url = dailyLogImageURL(from: imageFileName),
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

    private func dailyLogImageURL(from fileName: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    }

    private var timeActionCardItems: [TimeActionCardItem] {
        var items: [TimeActionCardItem] = []
        
        for action in timeActions {
            // 진행 중인 세션이 있는지 확인
            let runningSession = ongoingTimeSession(for: action)
            
            // 진행 중인 세션이 있으면 진행 중 카드만 표시
            if isViewingToday, runningSession != nil {
                items.append(.active(action: action, runningSession: runningSession))
            } else {
                // 선택한 날짜에 완료된 세션이 있는지 확인
                let completedSessionsForSelectedDay = timeSessions.filter {
                    $0.action?.persistentModelID == action.persistentModelID &&
                    !$0.isOngoing &&
                    $0.attributedDay == selectedDay
                }
                
                if let firstCompletedSession = completedSessionsForSelectedDay.first {
                    // 선택한 날짜에 완료된 세션이 있으면 완료 카드만 표시
                    items.append(.completed(session: firstCompletedSession, action: action))
                } else if isViewingToday {
                    // 오늘인 경우 시작 가능 카드 표시
                    items.append(.active(action: action, runningSession: nil))
                }
            }
        }
        
        return items
    }

    private var activeActions: [RoutineAction] {
        allActions.filter { $0.isActive(on: selectedDay, calendar: calendar) }
    }

    private var weeklyActions: [RoutineAction] {
        activeActions.filter { $0.type == .weeklyN }
    }

    private var timeActions: [RoutineAction] {
        activeActions.filter { action in
            guard action.type == .timeBased else { return false }
            // 오늘일 때만 진행 중인 타이머를 항상 표시
            if isViewingToday, let session = ongoingTimeSession(for: action), session.isOngoing {
                return true
            }
            // 그 외에는 선택한 요일에 해당하는 액션만 표시
            return action.isScheduled(on: selectedDay, calendar: calendar)
        }
    }

    private var dailyTodayActions: [RoutineAction] {
        activeActions.filter { $0.type == .weekdayRepeat && $0.isScheduled(on: selectedDay, calendar: calendar) }
    }

    /// 선택한 날짜의 오늘의 기록 엔트리(텍스트 또는 이미지가 있을 때만)
    private var dailyLogEntry: GratitudeEntry? {
        let dayStart = selectedDay.startOfDay(calendar: calendar)
        guard let entry = dailyLogEntries.first(where: { $0.day == dayStart }) else { return nil }
        guard (entry.text != nil && !entry.text!.isEmpty) || entry.imageURL != nil else { return nil }
        return entry
    }

    private func isEnabledForSelectedDay(_ action: RoutineAction) -> Bool {
        if action.type == .weeklyN { return true }
        return action.isScheduled(on: selectedDay, calendar: calendar)
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

    private func isCheckedOnSelectedDay(_ action: RoutineAction) -> Bool {
        allChecks.contains { $0.action?.persistentModelID == action.persistentModelID && $0.day == selectedDay }
    }

    private func weeklyCount(_ action: RoutineAction) -> Int {
        guard action.type == .weeklyN else { return 0 }
        return allChecks.filter {
            guard $0.action?.persistentModelID == action.persistentModelID else { return false }
            return $0.day >= selectedWeek.start && $0.day < selectedWeek.end
        }.count
    }

    private func toggleCheck(_ action: RoutineAction) {
        guard isEnabledForSelectedDay(action) else { return }
        withAnimation {
            if let existing = allChecks.first(where: { $0.action?.persistentModelID == action.persistentModelID && $0.day == selectedDay }) {
                modelContext.delete(existing)
            } else {
                let check = ActionCheck(day: selectedDay, createdAt: .now, action: action)
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
        let total = totalMinutes(for: action, on: selectedDay)
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
        return totalMinutes(for: action, on: selectedDay) >= action.timeTargetMinutes
    }

    private func ongoingTimeSession(for action: RoutineAction) -> TimeSession? {
        timeSessions.first { $0.action?.persistentModelID == action.persistentModelID && $0.isOngoing }
    }

    private func startTimer(for action: RoutineAction) {
        guard isViewingToday else { return }
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
        let key = "dailyEmoji.\(dayKey(for: date))"
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: key), emojis.contains(stored) {
            return stored
        }
        let randomEmoji = emojis.randomElement() ?? "🙂"
        defaults.set(randomEmoji, forKey: key)
        return randomEmoji
    }
    
    private func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date.startOfDay(calendar: calendar))
    }
    
    private var selectedDayBinding: Binding<Date> {
        Binding(
            get: { selectedDay },
            set: { selectedDay = $0.startOfDay(calendar: calendar) }
        )
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
