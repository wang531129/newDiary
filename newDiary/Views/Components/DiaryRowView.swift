import SwiftUI

// MARK: - 日記列表項視圖
struct DiaryRowView: View {
    let diary: DiaryEntry
    
    // 使用者偏好設置
    @AppStorage("titleFontSize") private var titleFontSize: Double = 18
    @AppStorage("contentFontSize") private var contentFontSize: Double = 14
    @AppStorage("titleFontColor") private var titleFontColor: String = "Green"
    @AppStorage("contentFontColor") private var contentFontColor: String = "Black"
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 日期部分
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(diary.date))
                    .font(.system(size: titleFontSize ))
                    .foregroundColor(Color.fromString(titleFontColor))
                    .fontWeight(.bold)
                
                // 天氣圖標
                HStack(spacing: 4) {
                    Image(systemName: diary.weather.icon)
                        .font(.system(size: contentFontSize))
                        .symbolRenderingMode(.multicolor)
                    
                    Text(diary.temperature)
                        .font(.system(size: contentFontSize * 0.9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, alignment: .leading)
            
            // 分隔線
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)
                .padding(.vertical, 2)
            
            // 記事預覽
            VStack(alignment: .leading, spacing: 4) {
                // 顯示記事開頭，最多預覽 100 個字符
                if !diary.thoughts.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        // 記事前面添加小圓點
                        Image(systemName: "circle.fill")
                            .font(.system(size: titleFontSize * 0.4))
                            .foregroundColor(Color.fromString(titleFontColor))
                            .padding(.top, 6)
                        
                        Text(diary.thoughts.prefix(100))
                            .font(.system(size: contentFontSize))
                            .foregroundColor(Color.fromString(contentFontColor))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                } else {
                    Text("沒有記事內容")
                        .font(.system(size: contentFontSize))
                        .foregroundColor(.secondary)
                        .italic()
                }
                
                // 顯示已有的分類記錄數量（如有）
                HStack(spacing: 10) {
                    if !diary.expenses.isEmpty {
                        categoryCounter(count: diary.expenses.count, type: .expense)
                    }
                    
                    if !diary.exercises.isEmpty {
                        categoryCounter(count: diary.exercises.count, type: .exercise)
                    }
                    
                    if !diary.sleeps.isEmpty {
                        categoryCounter(count: diary.sleeps.count, type: .sleep)
                    }
                    
                    if !diary.works.isEmpty {
                        categoryCounter(count: diary.works.count, type: .work)
                    }
                    
                    if !diary.relationships.isEmpty {
                        categoryCounter(count: diary.relationships.count, type: .relationship)
                    }
                    
                    if !diary.studies.isEmpty {
                        categoryCounter(count: diary.studies.count, type: .study)
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.textBackgroundColor).opacity(0.4))
        )
        .contentShape(Rectangle())
    }
    
    // 分類計數器視圖
    private func categoryCounter(count: Int, type: DiaryEntryType) -> some View {
        HStack(spacing: 2) {
            Image(systemName: type.icon)
                .font(.system(size: contentFontSize * 0.9))
                .foregroundColor(.secondary)
            
            Text("\(count)")
                .font(.system(size: contentFontSize * 0.8))
                .foregroundColor(.secondary)
        }
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
} 
