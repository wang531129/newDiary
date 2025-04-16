import Foundation
import SwiftUI

// MARK: - 通用輔助函數

// 將分鐘數格式化為h:mm格式
func formatMinutesToTimeString(_ minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60
    return String(format: "%d:%02d", hours, mins)
}

// 記錄調試信息
func logInfo(_ message: String) {
    #if DEBUG
    print("🔍 [INFO] \(message)")
    #endif
}

// 記錄錯誤信息
func logError(_ message: String) {
    #if DEBUG
    print("❌ [ERROR] \(message)")
    #endif
}

// MARK: - 動畫常數
struct AnimationConstants {
    static let quick = Animation.easeInOut(duration: 0.2)
    static let standard = Animation.easeInOut(duration: 0.3)
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.6)
    static let springSmall = Animation.spring(response: 0.2, dampingFraction: 0.7)
}

// MARK: - 自定義按鈕樣式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - 日期格式化擴展
extension Date {
    // 格式化日期為與日期選擇器相同的格式 (yyyy/M/d)
    func formattedForDatePicker() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: self)
    }
    
    // 獲取日期所在月份的第一天
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components)!
    }
    
    // 獲取日期所在月份的最後一天
    func endOfMonth() -> Date {
        let calendar = Calendar.current
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: self.startOfMonth())!
        return calendar.date(byAdding: .day, value: -1, to: startOfNextMonth)!
    }
}

// MARK: - 添加自定義游標修飾符
struct CursorModifier: ViewModifier {
    let cursor: NSCursor
    
    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

extension View {
    func customCursor(_ cursor: NSCursor) -> some View {
        modifier(CursorModifier(cursor: cursor))
    }
}

// 格式化日期為yyyy/M/d格式
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy/M/d"
    return formatter.string(from: date)
}

// 獲取當前月份的天數
func daysInMonth(for date: Date) -> Int {
    let calendar = Calendar.current
    if let range = calendar.range(of: .day, in: .month, for: date) {
        return range.count
    }
    return 30 // 默認值
}

// 獲取當前月份的第一天是星期幾 (0:星期日 ~ 6:星期六)
func firstDayOfMonth(for date: Date) -> Int {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month], from: date)
    if let firstDay = calendar.date(from: components) {
        return calendar.component(.weekday, from: firstDay) - 1
    }
    return 0 // 默認值為星期日
}

// 生成測試數據
func generateTestData() -> [DiaryEntry] {
    var entries: [DiaryEntry] = []
    
    // 獲取過去30天的日期
    let calendar = Calendar.current
    let today = Date()
    
    for i in 0..<30 {
        if let date = calendar.date(byAdding: .day, value: -i, to: today) {
            let entry = DiaryEntry(
                date: date,
                thoughts: "這是\(formatDate(date))的日記內容...",
                weather: WeatherType.allCases.randomElement() ?? .sunny,
                temperature: "\(Int.random(in: 20...30))°C"
            )
            entries.append(entry)
        }
    }
    
    return entries
} 