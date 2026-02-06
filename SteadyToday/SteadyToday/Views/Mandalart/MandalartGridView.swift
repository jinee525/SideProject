import SwiftUI

// 만다라트 그리드 뷰
struct MandalartGridView: View {
    let planYear: PlanYear?
    let categories: [MandalartCategory]

    @State private var selectedCategory: MandalartCategory?
    @State private var showingAddCategory = false
    @State private var showingAddAction = false
    @State private var editingCategory: MandalartCategory?
    @State private var editingAction: RoutineAction?
    @State private var showingGoalEditor = false
    @State private var goalTitleDraft: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let planYear = planYear {
                    // 상단: 목표-카테고리 (흰색 카드)
                    BorderedCardView {
                        categoryGrid(planYear: planYear)
                    }

                    // 하단: 카테고리-액션 (흰색 카드)
                    BorderedCardView {
                        if let selectedCategory = selectedCategory {
                            actionGrid(category: selectedCategory)
                        } else {
                            Text("카테고리를 선택해주세요")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }
                    }
                } else {
                    Text("계획을 먼저 세워주세요.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 80)
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showingAddCategory) {
            if let planYear = planYear {
                CreateEditModal(modalType: .category(planYear: planYear, category: nil))
            }
        }
        .sheet(isPresented: $showingAddAction) {
            if let selectedCategory = selectedCategory {
                CreateEditModal(modalType: .action(category: selectedCategory, action: nil))
            }
        }
        .sheet(item: $editingCategory) { category in
            CreateEditModal(modalType: .category(planYear: planYear, category: category))
        }
        .sheet(item: $editingAction) { action in
            if let selectedCategory = selectedCategory {
                CreateEditModal(modalType: .action(category: selectedCategory, action: action))
            }
        }
        .sheet(isPresented: $showingGoalEditor) {
            CreateEditModal(modalType: .goal(planYear: planYear, goalTitle: goalTitleDraft))
        }
        .onAppear {
            goalTitleDraft = planYear?.goalTitle ?? ""
        }
    }
    
    // 상단: 카테고리 그리드
    private func categoryGrid(planYear: PlanYear) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            // 첫 번째 행
            ForEach(0..<3) { index in
                categoryCell(at: index)
            }
            
            // 두 번째 행 (중앙에 목표)
            categoryCell(at: 3)
            centerGoalCell(goalTitle: planYear.goalTitle)
            categoryCell(at: 4)
            
            // 세 번째 행
            ForEach(5..<8) { index in
                categoryCell(at: index)
            }
        }
    }
    
    private func categoryCell(at index: Int) -> some View {
        let category = index < categories.count ? categories[index] : nil
        
        return Group {
            if let category = category {
                Button {
                    selectedCategory = category
                } label: {
                    VStack(spacing: 4) {
                        Text(category.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                        Text("\(category.actions.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(
                        selectedCategory?.id == category.id
                            ? CategoryColors.color(for: category.colorKey).opacity(1)
                            : CategoryColors.color(for: category.colorKey).opacity(0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            editingCategory = category
                        }
                )
            } else {
                // 빈 셀 - (+) 버튼
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func centerGoalCell(goalTitle: String) -> some View {
        VStack(spacing: 6) {
            if goalTitle.isEmpty {
                Text("연간 목표")
                    .font(.caption.weight(.semibold))
            } else {
                Text(goalTitle)
                    .font(.headline)
                    .foregroundStyle(AppColors.label)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .onLongPressGesture {
            goalTitleDraft = goalTitle
            showingGoalEditor = true
        }
    }
    
    // 하단: 액션 그리드
    private func actionGrid(category: MandalartCategory) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            // 첫 번째 행
            ForEach(0..<3) { index in
                actionCell(at: index, category: category)
            }
            
            // 두 번째 행 (중앙에 카테고리)
            actionCell(at: 3, category: category)
            centerCategoryCell(category: category)
            actionCell(at: 4, category: category)
            
            // 세 번째 행
            ForEach(5..<8) { index in
                actionCell(at: index, category: category)
            }
        }
    }
    
    private func actionCell(at index: Int, category: MandalartCategory) -> some View {
        let actions = category.actions.sorted { $0.categoryOrder < $1.categoryOrder }
        let action = index < actions.count ? actions[index] : nil
        
        return Group {
            if let action = action {
                VStack(spacing: 4) {
                    Text(action.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                    Text(action.type.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(CategoryColors.color(for: category.colorKey).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onLongPressGesture(minimumDuration: 0.5) {
                    editingAction = action
                }
            } else {
                // 빈 셀 - (+) 버튼
                Button {
                    showingAddAction = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func centerCategoryCell(category: MandalartCategory) -> some View {
        VStack(spacing: 6) {
            Text(category.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(CategoryColors.color(for: category.colorKey).opacity(1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
