import SwiftUI
import SwiftData
import PhotosUI

struct DailyLogEditModal: View {
    @Environment(\.modelContext) private var modelContext
    
    let day: Date
    
    @Query(sort: \GratitudeEntry.day, order: .reverse) private var dailyLogEntries: [GratitudeEntry]
    
    @State private var selectedDate: Date
    @State private var dailyLogText: String
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var existingImageURL: String?
    
    private var existingEntry: GratitudeEntry? {
        let dayStart = day.startOfDay(calendar: .steadyMondayCalendar)
        return dailyLogEntries.first { entry in
            entry.day == dayStart
        }
    }
    
    init(day: Date) {
        self.day = day
        _selectedDate = State(initialValue: day.startOfDay(calendar: .steadyMondayCalendar))
        _dailyLogText = State(initialValue: "")
    }
    
    var body: some View {
        CommonModal(
            title: "오늘의 기록",
            isValid: true,
            onSave: {
                save()
            }
        ) {
            Section {
                HStack(alignment: .center) {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("오늘을 기록해보세요!", text: $dailyLogText, axis: .vertical)
                    .lineLimit(3...10)
            }
            .environment(\.locale, Locale(identifier: "ko_KR"))
            
            Section {
                imageView
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            loadExistingEntry()
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                guard let newValue = newValue,
                      let data = try? await newValue.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                selectedImage = image
            }
        }
    }
    
    private func loadExistingEntry() {
        if let entry = existingEntry {
            selectedDate = entry.day
            dailyLogText = entry.text ?? ""
            existingImageURL = entry.imageURL
        } else {
            dailyLogText = ""
        }
    }
    
    private func save() {
        let dayStart = selectedDate.startOfDay(calendar: .steadyMondayCalendar)
        let trimmedText = dailyLogText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let entry: GratitudeEntry
        if let existing = existingEntry, existing.day == dayStart {
            entry = existing
        } else {
            // 날짜가 변경된 경우 새로 생성
            if let existing = existingEntry {
                modelContext.delete(existing)
            }
            entry = GratitudeEntry(day: dayStart)
            modelContext.insert(entry)
        }
        
        entry.text = trimmedText.isEmpty ? nil : trimmedText
        entry.updatedAt = .now
        
        // 이미지 저장
        if let image = selectedImage {
            if let imageURL = saveImage(image) {
                // 기존 이미지 삭제
                if let oldURL = entry.imageURL {
                    deleteImage(at: oldURL)
                }
                entry.imageURL = imageURL
            }
        } else if existingImageURL == nil {
            // 이미지가 삭제된 경우
            if let oldURL = entry.imageURL {
                deleteImage(at: oldURL)
            }
            entry.imageURL = nil
        }
        // 기존 이미지가 있고 새로운 이미지가 선택되지 않은 경우 유지
    }
    
    private func saveImage(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let fileName = "\(UUID().uuidString).jpg"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            return fileName
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    private func imageURL(from fileName: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(fileName)
    }
    
    private func deleteImage(at fileName: String) {
        guard let url = imageURL(from: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    private var hasImage: Bool {
        selectedImage != nil || existingImageURL != nil
    }
    
    @ViewBuilder
    private var imageView: some View {
        if let image = selectedImage {
            imageDisplayView(image: image)
        } else if let imageFileName = existingImageURL,
                  let url = imageURL(from: imageFileName),
                  let imageData = try? Data(contentsOf: url),
                  let image = UIImage(data: imageData) {
            imageDisplayView(image: image)
        } else {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func imageDisplayView(image: UIImage) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // 이미지가 있을 때만 버튼 표시
            if hasImage {
                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Text("변경")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.label)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.label.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        selectedImage = nil
                        selectedPhotoItem = nil
                        existingImageURL = nil
                    } label: {
                        Text("삭제")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.label)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.label.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
