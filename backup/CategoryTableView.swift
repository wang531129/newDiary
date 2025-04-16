import SwiftUI
import SwiftData
import Foundation

// Color 擴展，提供從字符串獲取顏色的方法
extension Color {
    static func fromString(_ colorName: String) -> Color {
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

// 使用已有的模型類型，不再定義新的類型
struct CategoryTableView: View {
    let type: DiaryEntryType
    let entries: [CategoryEntry]
    let diary: DiaryEntry
    let onAdd: () -> Void
    let onDelete: (IndexSet) -> Void
    let onEdit: (CategoryEntry) -> Void
    
    // 添加將分鐘數格式化為h:mm格式的函數
    private func formatMinutesToTimeString(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
    
    // SwiftData環境
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("titleFontSize") private var titleFontSize: Double = 22
    @AppStorage("contentFontSize") private var contentFontSize: Double = 16
    @AppStorage("titleFontColor") private var titleFontColor: String = "Green"
    @AppStorage("contentFontColor") private var contentFontColor: String = "White"
    
    // 目標偏好設置
    @AppStorage("monthlyExpenseLimit") private var monthlyExpenseLimit: Double = 20000
    @AppStorage("dailyExerciseGoal") private var dailyExerciseGoal: Double = 60
    @AppStorage("dailySleepGoal") private var dailySleepGoal: Double = 390
    @AppStorage("dailyWorkGoal") private var dailyWorkGoal: Double = 120
    @AppStorage("dailyRelationshipGoal") private var dailyRelationshipGoal: Double = 30
    @AppStorage("dailyStudyGoal") private var dailyStudyGoal: Double = 60
    
    // 使用SwiftData查詢來獲取所有日記條目
    @Query private var allDiaryEntries: [DiaryEntry]
    
    var total: Double {
        entries.reduce(0) { $0 + $1.number }
    }
    
    // 计算月度合计
    var monthlyTotal: Double {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: diary.date)
        let currentYear = calendar.component(.year, from: diary.date)
        
        // 过滤出同月的日记条目
        let monthDiaries = allDiaryEntries.filter { entry in
            let entryMonth = calendar.component(.month, from: entry.date)
            let entryYear = calendar.component(.year, from: entry.date)
            return entryMonth == currentMonth && entryYear == currentYear
        }
        
        // 根据类型获取并计算合计
        let monthlyEntries = monthDiaries.flatMap { diary -> [CategoryEntry] in
            switch type {
            case .expense: return diary.expenses
            case .exercise: return diary.exercises
            case .sleep: return diary.sleeps
            case .work: return diary.works
            case .relationship: return diary.relationships
            case .study: return diary.studies
            }
        }
        
        return monthlyEntries.reduce(0) { $0 + $1.number }
    }
    
    var nameLabel: String {
        switch type {
        case .expense: return "名稱"
        case .exercise: return "名稱"
        case .sleep: return "品質"
        case .work: return "名稱"
        case .relationship: return "姓名"
        case .study: return "名稱"
        }
    }
    
    var categoryLabel: String {
        switch type {
        case .expense: return "類別"
        case .exercise: return "運動類型"
        case .sleep: return "醒來次數"
        case .work: return "工作類型"
        case .relationship: return "關係類型"
        case .study: return "學習類型"
        }
    }
    
    var numberLabel: String {
        switch type {
        case .expense: return "金額"
        case .exercise: return "時間"
        case .sleep: return "時間"
        case .work: return "時長"
        case .relationship: return "時長"
        case .study: return "時長"
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Label(type.rawValue, systemImage: type.icon)
                    .font(.system(size: titleFontSize))
                    .fontWeight(.bold)
                    .foregroundColor(Color.fromString(titleFontColor))
                Spacer()
                Button(action: onAdd) {
                    Label("新增", systemImage: "plus.circle.fill")
                        .font(.system(size: contentFontSize))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            Table(entries) {
                TableColumn(nameLabel) { entry in
                    Text(entry.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: contentFontSize))
                        .foregroundColor(Color.fromString(contentFontColor))
                }
                TableColumn(categoryLabel) { entry in
                    Text(entry.category)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: contentFontSize))
                        .foregroundColor(Color.fromString(contentFontColor))
                }
                TableColumn(numberLabel) { entry in
                    if type == .expense {
                        Text(String(format: "%.0f", entry.number))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.system(size: contentFontSize))
                            .monospacedDigit()
                            .foregroundColor(Color.fromString(contentFontColor))
                    } else {
                        // 時間相關條目顯示為h:mm
                        Text(formatMinutesToTimeString(Int(entry.number)))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.system(size: contentFontSize))
                            .monospacedDigit()
                            .foregroundColor(Color.fromString(contentFontColor))
                    }
                }
                TableColumn("備注") { entry in
                    Text(entry.notes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: contentFontSize))
                        .foregroundColor(.secondary)
                }
                TableColumn("操作") { entry in
                    HStack(spacing: 16) {
                        Button(action: { onEdit(entry) }) {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: contentFontSize))
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                                onDelete(IndexSet([index]))
                            }
                        }) {
                            Image(systemName: "trash.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: contentFontSize))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(minHeight: 100)
            
            HStack {
                // 月合计
                HStack {
                    Label("月合計: ", systemImage: "calendar")
                    Group {
                        switch type {
                        case .expense:
                            // 支出：超出月支出上限則顯示紅色和😩表情符號，未超出顯示綠色和😍
                            let isOverLimit = monthlyTotal > monthlyExpenseLimit
                            Text(String(format: "%.0f", monthlyTotal))
                                .monospacedDigit()
                                .foregroundColor(isOverLimit ? .red : .green)
                            Text("\(isOverLimit ? "🥵" : "😍") 元")
                        case .exercise, .sleep, .work, .relationship, .study:
                            Text(formatMinutesToTimeString(Int(monthlyTotal))).monospacedDigit()
                            Text(" (\(String(format: "%.0f", monthlyTotal))分鐘)")
                        }
                    }
                }
                .font(.system(size: contentFontSize))
                
                Spacer()
                
                // 小计
                HStack {
                    Label("小計: ", systemImage: "sum")
                    Group {
                        switch type {
                        case .expense:
                            Text(String(format: "%.0f", total)).monospacedDigit()
                            Text(" 元")
                        case .exercise:
                            // 運動：達到或超過每日目標顯示綠色和😍，未達到顯示紅色和🥵
                            let isGoalMet = total >= dailyExerciseGoal
                            Text(formatMinutesToTimeString(Int(total)))
                                .monospacedDigit()
                                .foregroundColor(isGoalMet ? .green : .red)
                            Text("\(isGoalMet ? "😍" : "🥵") (\(String(format: "%.0f", total))分鐘)")
                        case .sleep:
                            // 睡眠：達到或超過每日目標顯示綠色和😍，未達到顯示紅色和🥵
                            let isGoalMet = total >= dailySleepGoal
                            Text(formatMinutesToTimeString(Int(total)))
                                .monospacedDigit()
                                .foregroundColor(isGoalMet ? .green : .red)
                            Text("\(isGoalMet ? "😍" : "🥵") (\(String(format: "%.0f", total))分鐘)")
                        case .work:
                            // 工作：達到或超過每日目標顯示綠色和😍，未達到顯示紅色和🥵
                            let isGoalMet = total >= dailyWorkGoal
                            Text(formatMinutesToTimeString(Int(total)))
                                .monospacedDigit()
                                .foregroundColor(isGoalMet ? .green : .red)
                            Text("\(isGoalMet ? "😍" : "🥵") (\(String(format: "%.0f", total))分鐘)")
                        case .relationship:
                            // 關係：達到或超過每日目標顯示綠色和😍，未達到顯示紅色和🥵
                            let isGoalMet = total >= dailyRelationshipGoal
                            Text(formatMinutesToTimeString(Int(total)))
                                .monospacedDigit()
                                .foregroundColor(isGoalMet ? .green : .red)
                            Text("\(isGoalMet ? "😍" : "🥵") (\(String(format: "%.0f", total))分鐘)")
                        case .study:
                            // 學習：達到或超過每日目標顯示綠色和😍，未達到顯示紅色和🥵
                            let isGoalMet = total >= dailyStudyGoal
                            Text(formatMinutesToTimeString(Int(total)))
                                .monospacedDigit()
                                .foregroundColor(isGoalMet ? .green : .red)
                            Text("\(isGoalMet ? "😍" : "🥵") (\(String(format: "%.0f", total))分鐘)")
                        }
                    }
                }
                .font(.system(size: contentFontSize))
            }
        }
    }
} 