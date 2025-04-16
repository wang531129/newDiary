import Foundation
import SwiftData

@Model
final class Reminder {
    var title: String
    var date: Date
    var isCompleted: Bool
    var repeatType: String  // "none", "daily", "weekly", "monthly"
    
    init(title: String, date: Date, isCompleted: Bool = false, repeatType: String = "none") {
        self.title = title
        self.date = date
        self.isCompleted = isCompleted
        self.repeatType = repeatType
        
        // 创建时自动检测重复类型
        self.detectRepeatType()
        
        // 打印初始化信息（调试用）
        print("初始化提醒: \(title), 重复类型: \(self.repeatType)")
    }
    
    // 旧的初始化方法兼容性
    init(title: String, date: Date, completed: Bool, repeatType: String = "none") {
        self.title = title
        self.date = date
        self.isCompleted = completed
        self.repeatType = repeatType
        
        // 创建时自动检测重复类型
        self.detectRepeatType()
        
        // 打印初始化信息（调试用）
        print("初始化提醒(兼容): \(title), 重复类型: \(self.repeatType)")
    }
    
    // 检测重复类型的方法
    private func detectRepeatType() {
        let lowercaseTitle = title.lowercased()
        let oldType = repeatType
        
        if lowercaseTitle.contains("everyday") || lowercaseTitle.contains("每日") || lowercaseTitle.contains("daily") {
            self.repeatType = "daily"
        } else if lowercaseTitle.contains("每週") || lowercaseTitle.contains("weekly") || lowercaseTitle.contains("每周") {
            self.repeatType = "weekly"
        } else if lowercaseTitle.contains("每月") || lowercaseTitle.contains("monthly") {
            self.repeatType = "monthly"
        }
        
        // 如果重复类型有变化，打印调试信息
        if oldType != repeatType {
            print("模型内部修复重复类型: \(title) 从 \(oldType) 改为 \(repeatType)")
        }
    }
    
    // 用于调试的方法
    func checkAndPrintRepeatType() {
        print("提醒检查: \(title), 当前重复类型: \(repeatType)")
        detectRepeatType()
        print("   检查后: \(repeatType)")
    }
}

// 所有重复类型的选项
enum ReminderRepeatType: String, CaseIterable, Identifiable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .none:
            return "不重複"
        case .daily:
            return "每日"
        case .weekly:
            return "每週"
        case .monthly:
            return "每月"
        }
    }
} 