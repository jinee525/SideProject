import SwiftUI

// MARK: - Section Title (List 헤더 등 공통 타이틀 스타일)

/// 오늘의 도전 / 이번 주 목표 / 오늘의 액션 등 섹션 타이틀 공통 스타일
struct SectionTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AppColors.secondaryLabel)
            .textCase(nil)
    }
}

// MARK: - Section Card (타이틀 + 컨텐츠)

/// 타이틀 + 컨텐츠를 묶는 공통 섹션. 배경 없이 내용에 포커스 (체크 색상이 탁해지지 않음)
struct SectionCardView<Content: View, Accessory: View>: View {
    let title: String
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        @ViewBuilder accessory: @escaping () -> Accessory,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.secondaryLabel)
                Spacer(minLength: 0)
                accessory()
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

extension SectionCardView where Accessory == EmptyView {
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.accessory = { EmptyView() }
        self.content = content
    }
}
