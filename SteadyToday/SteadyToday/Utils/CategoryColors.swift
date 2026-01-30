import SwiftUI

struct CategoryColorPreset: Identifiable, Hashable {
    let key: String
    let color: Color

    var id: String { key }
}

enum CategoryColors {
    // 파스텔 톤 팔레트 (opacity 없이도 부드러운 구분)
    static let presets: [CategoryColorPreset] = [
        .init(key: "red", color: Color(red: 1.0, green: 0.71, blue: 0.65)),       // 코랄
        .init(key: "orange", color: Color(red: 1.0, green: 0.84, blue: 0.75)),   // 피치
        .init(key: "yellow", color: Color(red: 0.96, green: 0.86, blue: 0.52)), // 버터
        .init(key: "green", color: Color(red: 0.66, green: 0.84, blue: 0.73)),   // 세이지
        .init(key: "mint", color: Color(red: 0.60, green: 0.85, blue: 0.78)),   // 민트
        .init(key: "teal", color: Color(red: 0.50, green: 0.74, blue: 0.79)),    // 더스티 틸
        .init(key: "cyan", color: Color(red: 0.53, green: 0.81, blue: 0.92)),    // 스카이
        .init(key: "blue", color: Color(red: 0.62, green: 0.71, blue: 0.95)),   // 페리윙클
        .init(key: "indigo", color: Color(red: 0.66, green: 0.70, blue: 0.91)),   // 라벤더 블루
        .init(key: "purple", color: Color(red: 0.79, green: 0.69, blue: 0.91)),  // 라벤더
        .init(key: "pink", color: Color(red: 0.97, green: 0.78, blue: 0.86)),     // 블러시
        .init(key: "gray", color: Color(red: 0.72, green: 0.72, blue: 0.75)),   // 웜 그레이
    ]

    static func color(for key: String?) -> Color {
        guard let key else { return .blue }
        return presets.first(where: { $0.key == key })?.color ?? .blue
    }
}

struct CategoryColorDot: View {
    let key: String?
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(CategoryColors.color(for: key))
            .frame(width: size, height: size)
    }
}

