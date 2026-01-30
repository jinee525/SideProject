import SwiftUI
import SwiftData

enum MandalartViewMode {
    case grid
    case list
}

struct MandalartView: View {
    @Environment(\.modelContext) private var modelContext

    private let calendar = Calendar.steadyMondayCalendar
    private var currentYear: Int { calendar.component(.year, from: Date()) }

    @Query private var years: [PlanYear]
    @Query private var categories: [MandalartCategory]

    @State private var goalTitleDraft: String = ""
    @State private var viewMode: MandalartViewMode = .grid

    init() {
        let year = Calendar.steadyMondayCalendar.component(.year, from: Date())
        _years = Query(filter: #Predicate<PlanYear> { $0.year == year })
        _categories = Query(
            filter: #Predicate<MandalartCategory> { $0.planYear?.year == year },
            sort: [SortDescriptor(\.sortOrder, order: .forward)]
        )
    }

    private var plan: PlanYear? { years.first }

    var body: some View {
        NavigationStack {
            Group {
                if viewMode == .grid {
                    MandalartGridView(planYear: plan, categories: categories)
                } else {
                    MandalartListView(planYear: plan, categories: categories, goalTitleDraft: $goalTitleDraft, onSaveGoal: saveGoalTitle)
                }
            }
            .navigationTitle("목표 세우기")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewMode = viewMode == .grid ? .list : .grid
                    } label: {
                        Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.3x3")
                            .foregroundStyle(AppColors.label)
                    }
                }
            }
            .onAppear {
                bootstrapIfNeeded()
                goalTitleDraft = plan?.goalTitle ?? ""
            }
        }
    }

    private func bootstrapIfNeeded() {
        if plan == nil {
            modelContext.insert(PlanYear(year: currentYear, goalTitle: ""))
        }
    }

    private func saveGoalTitle() {
        guard let plan else { return }
        plan.goalTitle = goalTitleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
