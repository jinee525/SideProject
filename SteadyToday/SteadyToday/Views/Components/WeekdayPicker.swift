import SwiftUI

struct WeekdayPicker: View {
    @Binding var mask: WeekdayMask

    var body: some View {
        HStack(spacing: 8) {
            dayButton("월", .mon)
            dayButton("화", .tue)
            dayButton("수", .wed)
            dayButton("목", .thu)
            dayButton("금", .fri)
            dayButton("토", .sat)
            dayButton("일", .sun)
        }
    }

    private func dayButton(_ label: String, _ day: WeekdayMask) -> some View {
        let isOn = mask.contains(day)
        return Button {
            if isOn { mask.remove(day) } else { mask.insert(day) }
        } label: {
            Text(label)
                .font(.callout.weight(.semibold))
                .foregroundStyle(isOn ? Color.white : AppColors.label)
                .frame(width: 32, height: 32)
                .background(isOn ? Color.accentColor : Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
