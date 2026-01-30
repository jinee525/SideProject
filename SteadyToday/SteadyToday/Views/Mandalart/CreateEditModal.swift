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
    @State private var hasStartDate: Bool = false
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date()
    
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
                _hasStartDate = State(initialValue: action.startDate != nil)
                _startDate = State(initialValue: action.startDate ?? Date())
                _hasEndDate = State(initialValue: action.endDate != nil)
                _endDate = State(initialValue: action.endDate ?? Date())
            } else {
                // 생성 모드: 기본적으로 시작 날짜를 오늘로 설정
                _hasStartDate = State(initialValue: true)
                _startDate = State(initialValue: Date())
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                contentSection
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                        dismiss()
                    }
                    .foregroundStyle(AppColors.label)
                    .disabled(!isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .foregroundStyle(AppColors.label)
                }
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
                Toggle("시작 날짜 설정", isOn: $hasStartDate)
                if hasStartDate {
                    DatePicker("시작 날짜", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                
                Toggle("종료 날짜 설정", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("종료 날짜", selection: $endDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .onChange(of: hasStartDate) { oldValue, newValue in
                            if newValue && endDate < startDate {
                                endDate = startDate
                            }
                        }
                        .onChange(of: startDate) { oldValue, newValue in
                            if hasEndDate && endDate < newValue {
                                endDate = newValue
                            }
                        }
                }
            }
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
            if hasStartDate && hasEndDate {
                let calendar = Calendar.steadyMondayCalendar
                let startDay = startDate.startOfDay(calendar: calendar)
                let endDay = endDate.startOfDay(calendar: calendar)
                if endDay < startDay { return false }
            }
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
                action.startDate = hasStartDate ? startDate : nil
                action.endDate = hasEndDate ? endDate : nil
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
                    startDate: hasStartDate ? startDate : nil,
                    endDate: hasEndDate ? endDate : nil,
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
