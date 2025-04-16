import SwiftUI
import SwiftData
import Foundation
import AppKit  // 添加 AppKit 導入，為了使用 NSCursor

// 適配器類型，用於連接 DiaryEntry 和 CustomDatePickerView
public class DiaryEntryAdapter {
    public var date: Date
    
    public init(date: Date) {
        self.date = date
    }
    
    // 從 DiaryEntry 創建適配器
    public static func from(_ entry: Any?) -> DiaryEntryAdapter? {
        if let entry = entry as? DiaryEntryAdapter {
            return entry
        }
        
        // 嘗試通過反射獲取日期屬性
        if let diaryEntry = entry as? Any {
            // 1. 使用Mirror反射获取属性
            let mirror = Mirror(reflecting: diaryEntry)
            for child in mirror.children {
                if child.label == "date", let date = child.value as? Date {
                    return DiaryEntryAdapter(date: date)
                }
            }
            
            // 2. 如果对象支持KVC，尝试使用value(forKey:)
            if let objcObject = diaryEntry as? NSObject {
                if objcObject.responds(to: Selector(("date"))) {
                    if let date = objcObject.value(forKey: "date") as? Date {
                        return DiaryEntryAdapter(date: date)
                    }
                }
            }
        }
        
        return nil
    }
}

// MARK: - 自定義日期選擇器
public struct CustomDatePickerView: View {
    @Binding var selectedDate: Date
    var titleFontColor: String
    var contentFontColor: String
    @Binding var selectedDiary: DiaryEntryAdapter?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 顯示模式: true表示使用popover形式
    var isPopover: Bool = false
    
    // 儲存所有日記條目的日期
    var diaryDates: [Date]
    
    // Calendar related properties
    @State private var currentMonth: Date = Date()
    
    // 创建一个设置了firstWeekday的Calendar实例
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // 1是星期日，2是星期一
        return cal
    }
    
    // 添加公共初始化器
    public init(selectedDate: Binding<Date>, titleFontColor: String, contentFontColor: String, selectedDiary: Binding<DiaryEntryAdapter?>, diaryDates: [Date] = [], isPopover: Bool = false) {
        self._selectedDate = selectedDate
        self.titleFontColor = titleFontColor
        self.contentFontColor = contentFontColor
        self._selectedDiary = selectedDiary
        self.diaryDates = diaryDates
        self.isPopover = isPopover
    }
    
    // 兼容原來的 DiaryEntry 類型的初始化器
    public init(selectedDate: Binding<Date>, titleFontColor: String, contentFontColor: String, selectedDiary: Binding<Any?>, diaryDates: [Date] = [], isPopover: Bool = false) {
        self._selectedDate = selectedDate
        self.titleFontColor = titleFontColor
        self.contentFontColor = contentFontColor
        self.diaryDates = diaryDates
        self.isPopover = isPopover
        
        // 使用適配器將 DiaryEntry 轉換為 DiaryEntryAdapter
        self._selectedDiary = Binding<DiaryEntryAdapter?>(
            get: {
                DiaryEntryAdapter.from(selectedDiary.wrappedValue)
            },
            set: { newValue in
                // 不需要設定回去，因為我們只關心日期
            }
        )
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Month and Year display
            HStack(spacing: 20) {
                Button {
                    withAnimation {
                        currentMonth = getPreviousMonth()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                }
                
                Text(extractMonthAndYear())
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(getColorFromString(titleFontColor))
                    .animation(.none)
                
                Button {
                    withAnimation {
                        currentMonth = getNextMonth()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            
            // Day of week headers
            let days = ["一", "二", "三", "四", "五", "六", "日"]
            HStack(spacing: 0) {
                ForEach(days.indices, id: \.self) { index in
                    Text(days[index])
                        .font(.callout)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(index == 5 || index == 6 ? .red : getColorFromString(contentFontColor))
                }
            }
            
            // Calendar grid
            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(extractDates()) { dateValue in
                    cardView(dateValue)
                        .onTapGesture {
                            // 只有過去和今天的日期才可點擊
                            if isDateClickable(dateValue.date) {
                                selectedDate = dateValue.date
                                updateSelectedDiary()
                            }
                        }
                        // 使用hover效果替代customCursor
                        .onHover { hovering in
                            // 添加明確檢查當前dateValue的day值，確保非有效日期不會顯示手形光標
                            if hovering && isDateClickable(dateValue.date) && dateValue.day > 0 {
                                NSCursor.pointingHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        }
                }
            }
            
            // 如果是 popover模式，添加確認按鈕
            if isPopover {
                Spacer()
                Button("確定") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom)
            }
        }
        .padding(.vertical)
        .onAppear {
            // 確保currentMonth與selectedDate同步
            currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) ?? Date()
            
            // 設置初始選中日記
            updateSelectedDiary()
            
            #if DEBUG
            print("CustomDatePickerView - 加載時日記日期數量: \(diaryDates.count)")
            #endif
        }
        .onChange(of: selectedDate) { oldValue, newValue in
            // 日期變更時確保月份視圖也同步更新
            if !calendar.isDate(oldValue, equalTo: newValue, toGranularity: .month) {
                currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: newValue)) ?? newValue
            }
            updateSelectedDiary()
        }
    }
    
    // 檢查日期是否可點擊（今天和之前的日期可點擊，未來日期不可點擊）
    private func isDateClickable(_ date: Date) -> Bool {
        // 確保日期是有效的當月日期（day > 0）
        let day = calendar.component(.day, from: date)
        let isValidDay = day > 0
        
        // 確保日期不在未來
        let isCurrentOrPastDate = date <= Date()
        
        // 兩個條件都滿足才可點擊
        return isValidDay && isCurrentOrPastDate
    }
    
    // Calendar Date Card View
    @ViewBuilder
    func cardView(_ dateValue: DateValue) -> some View {
        let isToday = calendar.isDate(dateValue.date, inSameDayAs: selectedDate)
        let isTodayDate = calendar.isDate(dateValue.date, inSameDayAs: Date()) // 判断是否是今天的日期
        
        // Check if date belongs to current month and is valid
        let isValidDay = dateValue.day > 0
        
        // Check if it's weekend (Saturday or Sunday)
        let weekday = calendar.component(.weekday, from: dateValue.date)
        let isWeekend = weekday == 1 || weekday == 7 // 1 = Sunday, 7 = Saturday
        
        // Check if date has diary entry
        let hasDiaryEntry = hasDiary(dateValue.date)
        
        // 檢查是否是未來日期（不可點擊）
        let isFutureDate = dateValue.date > Date()
        
        // 简化视图结构
        ZStack {
            // 如果是选中的日期，显示黄色方形
            if isToday && isValidDay {
                RoundedRectangle(cornerRadius: 12 )
                    .fill(Color.yellow)
                    .stroke(Color.red, lineWidth: 3.5)
                    .frame(width: 35, height: 35)
            }
            // 如果有日记条目，显示蓝色边框
            else if hasDiaryEntry && isValidDay {
                Circle()
                    .stroke(Color.blue, lineWidth: 1.5)
                    .frame(width: 32, height: 32)
            }
            // 非当前月份的日期占位，显示灰色背景
            else if !isValidDay {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 32, height: 32)
            }
            
            // 显示日期文本
            if isValidDay {
                Text("\(calendar.component(.day, from: dateValue.date))")
                    .font(.system(size: 15))
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(
                        isToday ? .black : 
                        (isFutureDate ? .gray.opacity(0.5) : // 未來日期顯示淺灰色
                         (isWeekend ? .red : getColorFromString(contentFontColor)))
                    )
            } else {
                // 空白占位符
                Text("")
            }
        }
        .frame(height: 35)
        .frame(maxWidth: .infinity)
        // 未來日期或非當月日期顯示禁止點擊的樣式
        .opacity(isFutureDate || !isValidDay ? 0.5 : 1.0)
    }
    
    // Extract Month and Year for title
    private func extractMonthAndYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M"
        return formatter.string(from: currentMonth)
    }
    
    // Get previous month
    private func getPreviousMonth() -> Date {
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) else {
            return currentMonth
        }
        return previousMonth
    }
    
    // Get next month
    private func getNextMonth() -> Date {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else {
            return currentMonth
        }
        return nextMonth
    }
    
    // Extract dates for the current month view
    private func extractDates() -> [DateValue] {
        let currentMonth = self.currentMonth
        
        guard let monthRange = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        
        var days = monthRange.compactMap { day -> DateValue in
            let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay)!
            return DateValue(day: day, date: date)
        }
        
        // 計算當月第一天是星期幾
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        
        // 調整日曆起始日（0表示不添加前一個月日期，1-7表示需要添加的天數）
        let leadingSpaces = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        if leadingSpaces > 0 {
            for _ in 0..<leadingSpaces {
                // 添加一個空的日期值代替前一個月的日期
                days.insert(DateValue(day: -1, date: Date()), at: 0)
            }
        }
        
        return days
    }
    
    // 檢查日期是否有日記
    private func hasDiary(_ date: Date) -> Bool {
        // 檢查是否有此日期的日記條目
        return diaryDates.contains { entryDate in
            calendar.isDate(entryDate, inSameDayAs: date)
        }
    }
    
    // Update selected diary based on selected date
    private func updateSelectedDiary() {
        // 由於我們只有日期數據，這個方法現在主要用於更新UI
        // 實際的日記選擇邏輯會在父視圖中處理
        if hasDiary(selectedDate) {
            self.selectedDiary = DiaryEntryAdapter(date: selectedDate)
        } else {
            self.selectedDiary = nil
        }
    }
    
    // 輔助方法來獲取顏色
    private func getColorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "white": return .white
        case "black": return .black
        case "gray": return .gray
        default: return .primary
        }
    }
}

// Helper struct for representing a date in the grid
public struct DateValue: Identifiable {
    public var id = UUID().uuidString
    public var day: Int
    public var date: Date
}

// 預覽視圖
struct CustomDatePickerView_Previews: PreviewProvider {
    static var previews: some View {
        // 建立一些範例日期
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!
        
        let sampleDates = [today, yesterday, twoDaysAgo, nextWeek]
        
        CustomDatePickerView(
            selectedDate: Binding.constant(Date()),
            titleFontColor: "Orange",
            contentFontColor: "White",
            selectedDiary: Binding.constant(nil),
            diaryDates: sampleDates,
            isPopover: true
        )
        .frame(width: 350, height: 400)
    }
} 
