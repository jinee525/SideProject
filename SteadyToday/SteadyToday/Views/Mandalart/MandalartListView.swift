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
        ScrollView {
            VStack(spacing: 20) {
                SectionCardView(title: "연간 목표") {
                    TextField("올해의 목표", text: $goalTitleDraft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { onSaveGoal() }
                }

                SectionCardView(title: "카테고리 (최대 8)") {
                    VStack(spacing: 0) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            NavigationLink {
                                CategoryDetailView(category: category)
                            } label: {
                                listRowContent(
                                    leading: {
                                        HStack(spacing: 12) {
                                            CategoryColorDot(key: category.colorKey, size: 12)
                                                .frame(width: 28)
                                            Text(category.name)
                                                .foregroundStyle(AppColors.label)
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            if index < categories.count - 1 || categories.count < 8 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }

                        if categories.count < 8 {
                            Button {
                                showingAddCategory = true
                            } label: {
                                listRowContent(
                                    leading: {
                                        Label("카테고리 추가", systemImage: "plus")
                                            .foregroundStyle(AppColors.label)
                                    },
                                    showChevron: false
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("카테고리는 최대 8개까지 만들 수 있어요.")
                                .font(.footnote)
                                .foregroundStyle(AppColors.secondaryLabel)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        }
                    }
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
    }
    
    private func deleteCategories(offsets: IndexSet) {
        withAnimation {
            for idx in offsets {
                modelContext.delete(categories[idx])
            }
        }
    }

    /// iOS 스타일 리스트 행: leading + Spacer + (chevron 또는 비움)
    private func listRowContent<L: View>(
        @ViewBuilder leading: () -> L,
        showChevron: Bool = true
    ) -> some View {
        HStack {
            leading()
            Spacer(minLength: 0)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
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
                    HStack(spacing: 12) {
                        CategoryColorDot(key: category.colorKey, size: 12)
                            .frame(width: 28)
                        Text(category.name)
                            .foregroundStyle(AppColors.label)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            } header: {
                Text("카테고리")
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
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.name)
                                    .foregroundStyle(AppColors.label)
                                Text(action.type.title)
                                    .font(.footnote)
                                    .foregroundStyle(AppColors.secondaryLabel)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteActions)

                if actionsSorted.count < 8 {
                    Button {
                        showingAddAction = true
                    } label: {
                        Label("액션 추가", systemImage: "plus")
                            .foregroundStyle(AppColors.label)
                    }
                } else {
                    Text("액션은 카테고리당 최대 8개까지 만들 수 있어요.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.pageBackground)
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
