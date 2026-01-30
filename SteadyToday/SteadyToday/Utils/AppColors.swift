import SwiftUI

/// 앱 전역에서 쓰는 공통 컬러 칩.
/// 완전 블랙 대신 부드러운 어두운 색 + 사용처별 opacity로 통일.
enum AppColors {
    // MARK: - Primary 계열 (라이트: 부드러운 검정, 다크: 부드러운 흰색)

    /// 메인 텍스트·강조 (제목, 본문, 버튼 라벨)
    static let label: Color = Color.primary.opacity(0.85)

    /// 선택된 셀 배경 (달력 선택일 등)
    static let selectedBackground: Color = Color.primary.opacity(0.12)

    /// 강조 테두리 (오늘 테두리, 구분선 등)
    static let border: Color = Color.primary.opacity(0.35)

    /// 아주 연한 구분선 (그리드, 디바이더)
    static let gridLine: Color = Color.primary.opacity(0.1)

    // MARK: - 보조 텍스트

    /// 보조 텍스트 (섹션 타이틀, 푸터, 캡션, 부가 설명)
    static let secondaryLabel: Color = Color.secondary
}
