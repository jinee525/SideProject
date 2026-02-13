import SwiftUI
import SwiftData

enum CreateEditModalType {
    case goal(planYear: PlanYear?, goalTitle: String)
    case category(planYear: PlanYear?, category: MandalartCategory?)
    case action(category: MandalartCategory, action: RoutineAction?)
}

struct CreateEditModal: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let modalType: CreateEditModalType

    private static var endOfCurrentYear: Date {
        let cal = Calendar.steadyMondayCalendar
        let year = cal.component(.year, from: Date())
        return cal.date(from: DateComponents(year: year, month: 12, day: 31)) ?? Date()
    }
    
    // Goal
    @State private var goalTitle: String = ""
    
    // Category
    @State private var categoryName: String = ""
    @State private var selectedColorKey: String = CategoryColors.presets.first?.key ?? "blue"
    
    // Action
    @State private var actionName: String = ""
    @State private var actionType: RoutineActionType = .weeklyN
    @State private var weeklyTargetN: Int = 3
    @State private var weekdays: WeekdayMask = [.mon, .wed, .fri]
    @State private var targetHours: Int = 1
    @State private var targetMinutes: Int = 0
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Self.endOfCurrentYear
    
    init(modalType: CreateEditModalType) {
        self.modalType = modalType
        
        switch modalType {
        case .goal(_, let goalTitle):
            _goalTitle = State(initialValue: goalTitle)
        case .category(_, let category):
            _categoryName = State(initialValue: category?.name ?? "")
            _selectedColorKey = State(initialValue: category?.colorKey ?? CategoryColors.presets.first?.key ?? "blue")
        case .action(let category, let action):
            if let action = action {
                // 수정 모드
                _actionName = State(initialValue: action.name)
                _actionType = State(initialValue: action.type)
                _weeklyTargetN = State(initialValue: action.weeklyTargetN)
                _weekdays = State(initialValue: WeekdayMask(rawValue: action.repeatWeekdaysRaw))
                _targetHours = State(initialValue: action.timeTargetMinutes / 60)
                _targetMinutes = State(initialValue: action.timeTargetMinutes % 60)
                _startDate = State(initialValue: action.startDate ?? Date())
                _endDate = State(initialValue: action.endDate ?? Self.endOfCurrentYear)
            } else {
                // 생성 모드: 시작=오늘, 종료=해당 연도 12/31
                _startDate = State(initialValue: Date())
                _endDate = State(initialValue: Self.endOfCurrentYear)
            }
        }
    }
    
    var body: some View {
        CommonModal(
            title: navigationTitle,
            isValid: isValid,
            onSave: {
                save()
            }
        ) {
            contentSection
            if isEditModeWithDeletable {
                Button {
                    deleteAndDismiss()
                } label: {
                    Text("삭제하기")
                        .font(.subheadline)
                        .foregroundStyle(Color.red.opacity(0.85))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        }
    }
    
    private var navigationTitle: String {
        switch modalType {
        case .goal:
            return "목표 수정"
        case .category(_, let category):
            return category == nil ? "카테고리 추가" : "카테고리 수정"
        case .action(_, let action):
            return action == nil ? "액션 추가" : "액션 수정"
        }
    }

    /// 수정 모드이면서 삭제 가능한 경우(카테고리/액션만, 목표는 제외)
    private var isEditModeWithDeletable: Bool {
        switch modalType {
        case .goal:
            return false
        case .category(_, let category):
            return category != nil
        case .action(_, let action):
            return action != nil
        }
    }

    private func deleteAndDismiss() {
        switch modalType {
        case .goal:
            break
        case .category(_, let category):
            if let category = category {
                modelContext.delete(category)
            }
        case .action(_, let action):
            if let action = action {
                modelContext.delete(action)
            }
        }
        dismiss()
    }
    
    @ViewBuilder
    private var contentSection: some View {
        switch modalType {
        case .goal:
            Section {
                TextField("연간 목표", text: $goalTitle)
            }
        case .category:
            Section {
                TextField("카테고리 이름", text: $categoryName)
            }
            Section {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                    ForEach(CategoryColors.presets) { preset in
                        Button {
                            selectedColorKey = preset.key
                        } label: {
                            ZStack {
                                Circle().fill(preset.color)
                                if selectedColorKey == preset.key {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("색상 \(preset.key)")
                    }
                }
            } header: {
                Text("색상")
                    .foregroundStyle(AppColors.label)
            }
        case .action:
            Section {
                TextField("액션 이름", text: $actionName)
                Picker("타입", selection: $actionType) {
                    ForEach(RoutineActionType.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
            }
            
            if actionType == .weeklyN {
                Section("주 N회") {
                    Stepper("목표: 주 \(weeklyTargetN)회", value: $weeklyTargetN, in: 1...7)
                }
            } else if actionType == .weekdayRepeat {
                Section("요일 반복") {
                    WeekdayPicker(mask: $weekdays)
                }
            } else if actionType == .timeBased {
                Section("목표 시간") {
                    WheelTimePicker(hours: $targetHours, minutes: $targetMinutes)
                }
                Section("반복 요일") {
                    WeekdayPicker(mask: $weekdays)
                }
            }
            
            Section("활성화 기간") {
                DatePicker("시작 날짜", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                DatePicker("종료 날짜", selection: $endDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .onChange(of: startDate) { _, newValue in
                        if endDate < newValue {
                            endDate = newValue
                        }
                    }
            }
            .environment(\.locale, Locale(identifier: "ko_KR"))
        }
    }
    
    private var isValid: Bool {
        switch modalType {
        case .goal:
            return !goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .category(let planYear, _):
            return !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && planYear != nil
        case .action:
            if actionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
            if actionType == .weekdayRepeat && weekdays.isEmpty { return false }
            if actionType == .timeBased && weekdays.isEmpty { return false }
            if actionType == .timeBased && (targetHours == 0 && targetMinutes == 0) { return false }
            // 날짜 유효성 검사: 종료 날짜가 시작 날짜보다 이전이면 안 됨
            let calendar = Calendar.steadyMondayCalendar
            let startDay = startDate.startOfDay(calendar: calendar)
            let endDay = endDate.startOfDay(calendar: calendar)
            if endDay < startDay { return false }
            return true
        }
    }
    
    private func save() {
        switch modalType {
        case .goal(let planYear, _):
            if let planYear = planYear {
                planYear.goalTitle = goalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case .category(let planYear, let category):
            guard let planYear else { return }
            
            if let category = category {
                // 수정 모드
                category.name = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                category.colorKey = selectedColorKey
            } else {
                // 생성 모드
                let nextOrder = (planYear.categories.map(\.sortOrder).max() ?? -1) + 1
                let newCategory = MandalartCategory(
                    name: categoryName.trimmingCharacters(in: .whitespacesAndNewlines),
                    colorKey: selectedColorKey,
                    sortOrder: nextOrder,
                    planYear: planYear
                )
                modelContext.insert(newCategory)
                planYear.categories.append(newCategory)
            }
        case .action(let category, let action):
            if let action = action {
                // 수정 모드
                action.name = actionName.trimmingCharacters(in: .whitespacesAndNewlines)
                action.type = actionType
                action.weeklyTargetN = weeklyTargetN
                action.repeatWeekdays = weekdays
                action.timeRecordMode = .timer
                action.timeTargetMinutes = targetHours * 60 + targetMinutes
                action.startDate = startDate
                action.endDate = endDate
            } else {
                // 생성 모드
                let nextCategoryOrder = (category.actions.map(\.categoryOrder).max() ?? -1) + 1
                var fd = FetchDescriptor<RoutineAction>(sortBy: [SortDescriptor(\.todayOrder, order: .reverse)])
                fd.fetchLimit = 1
                let maxTodayOrder = (try? modelContext.fetch(fd).first?.todayOrder) ?? -1
                let newAction = RoutineAction(
                    name: actionName.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: actionType,
                    weeklyTargetN: weeklyTargetN,
                    repeatWeekdays: weekdays,
                    isActive: true,
                    startDate: startDate,
                    endDate: endDate,
                    todayOrder: maxTodayOrder + 1,
                    categoryOrder: nextCategoryOrder,
                    category: category,
                    timeRecordMode: .timer,
                    timeTargetMinutes: targetHours * 60 + targetMinutes
                )
                modelContext.insert(newAction)
                category.actions.append(newAction)
            }
        }
    }
}
