import SwiftUI
import SwiftData

/// 기록 탭: 오늘의 기록(로그)을 피드 형식으로 세로 나열. 최신 날짜가 위.
struct HistoryDailyLogView: View {
    private let calendar = Calendar.steadyMondayCalendar

    @Query(sort: \GratitudeEntry.day, order: .reverse) private var allEntries: [GratitudeEntry]

    /// 텍스트 또는 이미지가 있는 엔트리만 (피드에 표시할 목록)
    private var feedEntries: [GratitudeEntry] {
        allEntries.filter { entry in
            (entry.text != nil && !entry.text!.isEmpty) || entry.imageURL != nil
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(feedEntries) { entry in
                    logCard(entry: entry)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollContentBackground(.hidden)
    }

    private func logCard(entry: GratitudeEntry) -> some View {
        let dayStart = entry.day.startOfDay(calendar: calendar)
        return VStack(alignment: .leading, spacing: 12) {
            // 타이틀: 날짜
            Text(dayTitle(dayStart))
                .font(.headline)
                .foregroundStyle(AppColors.label)

            if let text = entry.text, !text.isEmpty {
                Text(text)
                    .font(.body)
                    .foregroundStyle(AppColors.label)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let imageFileName = entry.imageURL,
               let url = imageURL(from: imageFileName),
               let imageData = try? Data(contentsOf: url),
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppColors.cardCornerRadius, style: .continuous))
    }

    private func dayTitle(_ day: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (E)"
        return f.string(from: day)
    }

    private func imageURL(from fileName: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(fileName)
    }
}
