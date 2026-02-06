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

// MARK: - Bordered Card (타이틀 없이 컨텐츠만 카드)

/// 컨텐츠만 감싸는 흰색 카드. 달력·블록 등에 사용.
struct BorderedCardView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppColors.cardCornerRadius, style: .continuous))
    }
}

// MARK: - Section Card (타이틀 + 컨텐츠)

/// 타이틀 + 컨텐츠를 묶는 공통 섹션. iOS 설정 스타일(연한 배경 위 흰색 카드).
/// - **타이틀 영역**: 왼쪽 텍스트, 오른쪽 도우미 버튼 등 옵션(accessory)
/// - **컨텐츠 영역**: 리스트, 카드 등 자식 뷰를 그대로 전달
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
        VStack(alignment: .leading, spacing: 8) {
            // 타이틀 영역: 왼쪽 텍스트, 오른쪽 옵션(도우미 버튼 등)
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.headline)
                Spacer(minLength: 0)
                accessory()
            }
            .padding(.horizontal, 4)

            // 컨텐츠 영역: 리스트, 카드 등 child
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppColors.cardCornerRadius, style: .continuous))
    }
}

extension SectionCardView where Accessory == EmptyView {
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.accessory = { EmptyView() }
        self.content = content
    }
}
