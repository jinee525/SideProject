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
        MainTabLayout(title: "목표 세우기", titleAccessory: { MandalartGuideButton() }) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if viewMode == .grid {
                        MandalartGridView(planYear: plan, categories: categories)
                    } else {
                        MandalartListView(planYear: plan, categories: categories, goalTitleDraft: $goalTitleDraft, onSaveGoal: saveGoalTitle)
                    }
                }

                // 그리드-리스트 전환 버튼 (일단 미사용)
                // Button {
                //     viewMode = viewMode == .grid ? .list : .grid
                // } label: {
                //     Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.3x3")
                //         .font(.title2)
                //         .foregroundStyle(.white)
                //         .frame(width: 56, height: 56)
                //         .background(
                //             Circle()
                //                 .fill(AppColors.label)
                //         )
                //         .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                // }
                // .padding(.trailing, 20)
                // .padding(.bottom, 20)
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

// MARK: - 만다라트 가이드 (?) 버튼 + 팝오버

private struct MandalartGuideButton: View {
    @State private var showGuide = false

    var body: some View {
        Button {
            showGuide = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showGuide, attachmentAnchor: .point(UnitPoint(x: 0.5, y: 0.8))) {
            MandalartGuideView()
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct MandalartGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("만다라트 계획 가이드")
                    .font(.headline)

                guideSection(
                    number: 1,
                    title: "만다라트란?",
                    body: "한 가지 목표를 8개의 영역(카테고리)으로 나누고, 각 영역을 다시 8개의 실행(액션)으로 쪼개는 목표 설계 방법이에요. 올해 목표 → 카테고리 8개 → 카테고리당 액션 8개로 구체화합니다."
                )

                guideSection(
                    number: 2,
                    title: "빈 셀과 수정",
                    body: "빈 셀은 (+) 버튼으로 새로 만들 수 있어요. 이미 있는 카테고리·액션 셀은 꾹 누르면 수정/삭제할 수 있습니다."
                )

                guideSection(
                    number: 3,
                    title: "목표–카테고리 / 카테고리–액션 표",
                    body: "• 위쪽 표(목표–카테고리): 중앙이 올해 목표, 주변 8칸이 카테고리예요. 카테고리를 탭하면 아래 표에 해당 액션들이 나타납니다.\n• 아래쪽 표(카테고리–액션): 선택한 카테고리의 8개 액션을 보여줍니다. 중앙은 카테고리 이름, 주변 8칸이 액션이에요."
                )
            }
            .padding(16)
            .frame(width: 300)
        }
    }

    private func guideSection(number: Int, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            Text(body)
                .font(.footnote)
                .foregroundStyle(AppColors.secondaryLabel)
        }
    }
}
