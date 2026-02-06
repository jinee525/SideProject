import SwiftUI

/// 각 탭 메인 페이지에서 사용하는 공통 레이아웃
/// - 큰 타이틀 중앙 정렬
/// - 선택적으로 좌우 네비게이션 버튼, 타이틀 옆 액세서리(예: 가이드 버튼) 추가 가능
struct MainTabLayout<Content: View, TitleAccessory: View>: View {
    let title: String
    let leftButton: (() -> Void)?
    let rightButton: (() -> Void)?
    let showLeftButton: Bool
    let showRightButton: Bool
    let titleAccessory: TitleAccessory
    let content: Content

    init(
        title: String,
        showLeftButton: Bool = false,
        showRightButton: Bool = false,
        onLeftTap: (() -> Void)? = nil,
        onRightTap: (() -> Void)? = nil,
        @ViewBuilder titleAccessory: @escaping () -> TitleAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showLeftButton = showLeftButton
        self.showRightButton = showRightButton
        self.leftButton = onLeftTap
        self.rightButton = onRightTap
        self.titleAccessory = titleAccessory()
        self.content = content()
    }

    /// 헤더 배경: 상단 solid(라이트/다크 대응) + 하단만 흰색→투명 그라데이션(스크롤 시 콘텐츠가 비침)
    private var headerBackground: some View {
        LinearGradient(
            stops: [
                .init(color: AppColors.cardBackground, location: 0),
                .init(color: AppColors.cardBackground, location: 0.8),
                .init(color: AppColors.cardBackground.opacity(0.7), location: 0.9),
                .init(color: AppColors.cardBackground.opacity(0.35), location: 0.95),
                .init(color: AppColors.cardBackground.opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.pageBackground)
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top, spacing: 0) {
                    ZStack(alignment: .center) {
                        // 타이틀은 항상 화면 가운데
                        Text(title)
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity)

                        // 버튼/액세서리는 위에 올림
                        HStack(spacing: 0) {
                            Group {
                                if showLeftButton {
                                    Button {
                                        leftButton?()
                                    } label: {
                                        Image(systemName: "chevron.left")
                                            .font(.title3)
                                            .foregroundStyle(AppColors.label.opacity(0.2))
                                            .frame(width: 32, height: 32)
                                            .background(Circle().fill(AppColors.label.opacity(0.08)))
                                    }
                                } else {
                                    Color.clear
                                        .frame(width: 32, height: 32)
                                }
                            }

                            Spacer()

                            titleAccessory
                                .frame(width: 32, height: 32)

                            Group {
                                if showRightButton {
                                    Button {
                                        rightButton?()
                                    } label: {
                                        Image(systemName: "chevron.right")
                                            .font(.title3)
                                            .foregroundStyle(AppColors.label.opacity(0.2))
                                            .frame(width: 32, height: 32)
                                            .background(Circle().fill(AppColors.label.opacity(0.08)))
                                    }
                                } else {
                                    Color.clear
                                        .frame(width: 32, height: 32)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .background(headerBackground.ignoresSafeArea(edges: .top))
                }
        }
    }
}

extension MainTabLayout where TitleAccessory == EmptyView {
    init(
        title: String,
        showLeftButton: Bool = false,
        showRightButton: Bool = false,
        onLeftTap: (() -> Void)? = nil,
        onRightTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showLeftButton = showLeftButton
        self.showRightButton = showRightButton
        self.leftButton = onLeftTap
        self.rightButton = onRightTap
        self.titleAccessory = EmptyView()
        self.content = content()
    }
}
