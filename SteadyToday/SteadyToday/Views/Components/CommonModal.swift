import SwiftUI

/// 공통 모달 컴포넌트 - 상단 취소/저장 버튼, 타이틀, Form 구조를 제공
struct CommonModal<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    let isValid: Bool
    let onSave: () -> Void
    let onCancel: (() -> Void)?
    @ViewBuilder let content: () -> Content
    
    init(
        title: String,
        isValid: Bool = true,
        onSave: @escaping () -> Void,
        onCancel: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.isValid = isValid
        self.onSave = onSave
        self.onCancel = onCancel
        self.content = content
    }
    
    var body: some View {
        NavigationStack {
            Form {
                content()
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave()
                        dismiss()
                    }
                    .foregroundStyle(AppColors.label)
                    .disabled(!isValid)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        if let onCancel = onCancel {
                            onCancel()
                        }
                        dismiss()
                    }
                    .foregroundStyle(AppColors.label)
                }
            }
        }
    }
}
