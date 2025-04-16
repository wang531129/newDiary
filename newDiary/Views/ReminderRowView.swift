import SwiftUI
import SwiftData

struct ReminderRowView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteConfirmation = false
    let reminder: Reminder
    
    // 創建一個引用本地modelContext的reminderService
    private var reminderService: ReminderService {
        ReminderService(modelContext: modelContext)
    }
    
    // 自定義日期格式化器
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
    
    // 自定義時間格式化器
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
    
    // 獲取重復類型的顏色
    private func getRepeatColor(for repeatType: String) -> Color {
        switch repeatType {
        case "daily":
            return .yellow
        case "weekly":
            return .green
        case "monthly":
            return .red
        default:
            return .white // 無重復使用白色
        }
    }
    
    // 獲取帶前綴的標題
    private func getTitleWithPrefix() -> String {
        let prefix: String
        switch reminder.repeatType {
        case "daily":
            prefix = "每日: "
        case "weekly":
            prefix = "每週: "
        case "monthly":
            prefix = "每月: "
        default:
            prefix = ""
        }
        return prefix + reminder.title
    }
    
    var body: some View {
        ZStack {
            // 背景色 - 使用對應的提醒類型顏色
            RoundedRectangle(cornerRadius: 8)
                .fill(getRepeatColor(for: reminder.repeatType).opacity(0.2))
                .padding(.vertical, 1)
            
            // 內容
            HStack {
                // 左側狀態指示器
                Circle()
                    .fill(getRepeatColor(for: reminder.repeatType))
                    .frame(width: 12, height: 12)
                    .padding(.trailing, 4)
                    // 當使用白色時，添加邊框以便在深色背景下可見
                    .overlay(
                        reminder.repeatType == "none" ?
                        Circle().stroke(Color.gray, lineWidth: 1) : nil
                    )
                
                VStack(alignment: .leading) {
                    HStack {
                        Text(getTitleWithPrefix())
                            .fontWeight(.bold)
                            .foregroundColor(reminder.isCompleted ? .secondary : getRepeatColor(for: reminder.repeatType))
                            .strikethrough(reminder.isCompleted)
                        
                        if reminder.isCompleted {
                            Text("(已完成)")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        // 時間
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(timeFormatter.string(from: reminder.date))
                                .font(.caption)
                        }
                        
                        // 日期
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(dateFormatter.string(from: reminder.date))
                                .font(.caption)
                        }
                        
                        // 重復類型
                        if reminder.repeatType != "none" {
                            HStack(spacing: 2) {
                                Image(systemName: getRepeatIcon(for: reminder.repeatType))
                                    .font(.caption2)
                                Text(getRepeatText(for: reminder.repeatType))
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(getRepeatColor(for: reminder.repeatType))
                        }
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 完成/取消完成按鈕
                Button(action: {
                    if reminder.isCompleted {
                        // 取消完成
                        reminder.isCompleted = false
                        try? modelContext.save()
                    } else {
                        // 標記為完成
                        reminderService.completeReminder(reminder)
                    }
                    // 發送通知，以便其他視圖刷新
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshReminders"), object: nil)
                }) {
                    Image(systemName: reminder.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle")
                        .foregroundColor(reminder.isCompleted ? .orange : .green)
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
                .help(reminder.isCompleted ? "取消完成標記" : "標記為完成")
                
                // 刪除按鈕
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash.circle")
                        .foregroundColor(.red)
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
                .help("刪除提醒")
                .confirmationDialog("確定要刪除這個提醒嗎？", isPresented: $showDeleteConfirmation) {
                    Button("刪除", role: .destructive) {
                        reminderService.deleteReminder(reminder)
                        // 發送通知，以便其他視圖刷新
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshReminders"), object: nil)
                    }
                    Button("取消", role: .cancel) {}
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
        .onAppear {
            // 檢查並修復提醒的重復類型
            checkAndFixRepeatType()
        }
    }
    
    private func getRepeatIcon(for repeatType: String) -> String {
        switch repeatType {
        case "daily":
            return "arrow.clockwise.circle"
        case "weekly":
            return "calendar.badge.clock"
        case "monthly":
            return "calendar.circle"
        default:
            return "bell"
        }
    }
    
    private func getRepeatText(for repeatType: String) -> String {
        switch repeatType {
        case "daily":
            return "每日"
        case "weekly":
            let weekday = Calendar.current.component(.weekday, from: reminder.date)
            let weekdaySymbol = Calendar.current.shortWeekdaySymbols[weekday - 1]
            return "每週\(weekdaySymbol)"
        case "monthly":
            let day = Calendar.current.component(.day, from: reminder.date)
            return "每月\(day)日"
        default:
            return "一次性"
        }
    }
    
    // 檢查並修復提醒的重復類型
    private func checkAndFixRepeatType() {
        // 如果提醒標題包含特定關鍵詞，但重復類型不匹配，則修復它
        let title = reminder.title.lowercased()
        
        if (title.contains("everyday") || title.contains("每日") || title.contains("daily")) && reminder.repeatType != "daily" {
            print("修復提醒類型 - ReminderRowView: 將 \(reminder.title) 從 \(reminder.repeatType) 修改為 daily")
            reminder.repeatType = "daily"
            try? modelContext.save()
        } else if (title.contains("每週") || title.contains("weekly") || title.contains("每周")) && reminder.repeatType != "weekly" {
            print("修復提醒類型 - ReminderRowView: 將 \(reminder.title) 從 \(reminder.repeatType) 修改為 weekly")
            reminder.repeatType = "weekly"
            try? modelContext.save()
        } else if (title.contains("每月") || title.contains("monthly")) && reminder.repeatType != "monthly" {
            print("修復提醒類型 - ReminderRowView: 將 \(reminder.title) 從 \(reminder.repeatType) 修改為 monthly")
            reminder.repeatType = "monthly"
            try? modelContext.save()
        }
    }
}
