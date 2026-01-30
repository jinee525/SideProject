import SwiftUI
import SwiftData

struct MandalartListView: View {
    @Environment(\.modelContext) private var modelContext
    let planYear: PlanYear?
    let categories: [MandalartCategory]
    @Binding var goalTitleDraft: String
    let onSaveGoal: () -> Void
    
    @State private var showingAddCategory = false
    
    var body: some View {
        List {
            Section("연간 목표") {
                TextField("올해의 목표", text: $goalTitleDraft)
                    .onSubmit { onSaveGoal() }
            }

            Section("카테고리 (최대 8)") {
                ForEach(categories) { category in
                    NavigationLink {
                        CategoryDetailView(category: category)
                    }                     label: {
                        HStack {
                            CategoryColorDot(key: category.colorKey, size: 12)
                                .frame(width: 28)
                            Text(category.name)
                                .foregroundStyle(AppColors.label)
                        }
                    }
                }
                .onDelete(perform: deleteCategories)

                if categories.count < 8 {
                    Button {
                        showingAddCategory = true
                    } label: {
                        Label("카테고리 추가", systemImage: "plus")
                    }
                } else {
                    Text("카테고리는 최대 8개까지 만들 수 있어요.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            if let planYear = planYear {
                CreateEditModal(modalType: .category(planYear: planYear, category: nil))
            }
        }
    }
    
    private func deleteCategories(offsets: IndexSet) {
        withAnimation {
            for idx in offsets {
                modelContext.delete(categories[idx])
            }
        }
    }
}

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let category: MandalartCategory

    @State private var showingAddAction = false
    @State private var editingAction: RoutineAction?
    @State private var showingCategoryEditor = false

    private var actionsSorted: [RoutineAction] {
        category.actions.sorted { $0.categoryOrder < $1.categoryOrder }
    }

    var body: some View {
        List {
            Section {
                Button {
                    showingCategoryEditor = true
                } label: {
                    HStack {
                        CategoryColorDot(key: category.colorKey, size: 14)
                            .frame(width: 28, height: 28)
                        Text(category.name)
                            .foregroundStyle(AppColors.label)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                }
                .buttonStyle(.plain)
            } footer: {
                Text("카테고리를 눌러 이름과 색상을 수정할 수 있어요.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            Section("액션 (최대 8)") {
                ForEach(actionsSorted) { action in
                    Button {
                        editingAction = action
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.name)
                                .foregroundStyle(AppColors.label)
                            Text(action.type.title)
                                .font(.footnote)
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteActions)

                if actionsSorted.count < 8 {
                    Button {
                        showingAddAction = true
                    } label: {
                        Label("액션 추가", systemImage: "plus")
                    }
                } else {
                    Text("액션은 카테고리당 최대 8개까지 만들 수 있어요.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
        }
        .navigationTitle("카테고리")
        .sheet(isPresented: $showingAddAction) {
            CreateEditModal(modalType: .action(category: category, action: nil))
        }
        .sheet(item: $editingAction) { action in
            CreateEditModal(modalType: .action(category: category, action: action))
        }
        .sheet(isPresented: $showingCategoryEditor) {
            CreateEditModal(modalType: .category(planYear: category.planYear, category: category))
        }
    }

    private func deleteActions(offsets: IndexSet) {
        withAnimation {
            for idx in offsets {
                let action = actionsSorted[idx]
                category.actions.removeAll { $0.persistentModelID == action.persistentModelID }
                modelContext.delete(action)
            }
        }
    }
}
