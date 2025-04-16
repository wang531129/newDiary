import Foundation
import SwiftData

class ReminderService {
    let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // 标记提醒为已完成，并处理重复逻辑
    func completeReminder(_ reminder: Reminder) {
        // 如果是非重复提醒，直接标记为完成
        if reminder.repeatType == "none" {
            reminder.isCompleted = true
            try? modelContext.save()
            return
        }
        
        // 对于重复提醒，创建下一个重复提醒，但保留当前提醒
        createNextReminder(from: reminder)
        
        // 标记当前提醒为已完成而非删除
        reminder.isCompleted = true
        try? modelContext.save()
    }
    
    // 创建下一个重复提醒
    private func createNextReminder(from reminder: Reminder) {
        let nextDate = calculateNextDate(for: reminder)
        
        let newReminder = Reminder(
            title: reminder.title,
            date: nextDate,
            isCompleted: false,
            repeatType: reminder.repeatType
        )
        
        modelContext.insert(newReminder)
        try? modelContext.save()
    }
    
    // 计算下一个重复日期
    private func calculateNextDate(for reminder: Reminder) -> Date {
        let calendar = Calendar.current
        let currentDate = reminder.date
        
        switch reminder.repeatType {
        case "daily":
            // 下一天的同一时间
            return calendar.date(byAdding: .day, value: 1, to: currentDate) ?? Date()
            
        case "weekly":
            // 下一周的同一天
            return calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? Date()
            
        case "monthly":
            // 下个月的同一天
            // 注意：如果当月的日数比下月多，会自动调整到下月的最后一天
            return calendar.date(byAdding: .month, value: 1, to: currentDate) ?? Date()
            
        default:
            // 默认返回当前日期
            return currentDate
        }
    }
    
    // 智能检测提醒的重复类型
    func detectAndFixRepeatType(_ reminder: Reminder) {
        // 如果标题包含特定关键词，则设置对应的重复类型
        let title = reminder.title.lowercased()
        
        if title.contains("everyday") || title.contains("每日") || title.contains("daily") {
            if reminder.repeatType != "daily" {
                print("修正提醒类型：将 \(reminder.title) 从 \(reminder.repeatType) 修改为 daily")
                reminder.repeatType = "daily"
                try? modelContext.save()
            }
        } else if title.contains("每週") || title.contains("weekly") || title.contains("每周") {
            if reminder.repeatType != "weekly" {
                print("修正提醒类型：将 \(reminder.title) 从 \(reminder.repeatType) 修改为 weekly")
                reminder.repeatType = "weekly"
                try? modelContext.save()
            }
        } else if title.contains("每月") || title.contains("monthly") {
            if reminder.repeatType != "monthly" {
                print("修正提醒类型：将 \(reminder.title) 从 \(reminder.repeatType) 修改为 monthly")
                reminder.repeatType = "monthly"
                try? modelContext.save()
            }
        }
    }
    
    // 获取今天的提醒（接受includeCompleted参数，可以筛选已完成/未完成的提醒）
    func getTodayReminders(includeCompleted: Bool = true) -> [Reminder] {
        do {
            // 创建查询描述符
            var descriptor = FetchDescriptor<Reminder>()
            descriptor.sortBy = [SortDescriptor(\Reminder.date)]
            
            // 执行查询获取所有提醒
            let reminders = try modelContext.fetch(descriptor)
            
            // 首先检查和修复所有提醒的重复类型
            for reminder in reminders {
                detectAndFixRepeatType(reminder)
            }
            
            // 处理过期的重复提醒
            processOverdueRepeatReminders(reminders)
            
            // 筛选提醒（不再限制为当天）
            return reminders.filter { reminder in
                // 如果includeCompleted为true，则返回所有提醒；否则只返回未完成的提醒
                return includeCompleted || !reminder.isCompleted
            }
        } catch {
            print("获取提醒失败: \(error)")
            return []
        }
    }
    
    // 重命名该方法以更好地反映其功能：获取所有提醒
    func getAllReminders(includeCompleted: Bool = true) -> [Reminder] {
        return getTodayReminders(includeCompleted: includeCompleted)
    }
    
    // 获取未完成的提醒
    func getUncompletedReminders() -> [Reminder] {
        // 确保只返回未完成的提醒
        return getTodayReminders().filter { reminder in
            return !reminder.isCompleted
        }
    }
    
    // 处理过期的重复提醒
    private func processOverdueRepeatReminders(_ reminders: [Reminder]) {
        let now = Date()
        
        for reminder in reminders {
            // 只处理重复类型且未完成的提醒
            if reminder.repeatType != "none" && !reminder.isCompleted && reminder.date < now {
                // 计算新的下一次提醒日期
                var nextDate = calculateNextDate(for: reminder)
                
                // 如果下一次日期仍然在过去，继续计算直到找到未来的日期
                while nextDate < now {
                    switch reminder.repeatType {
                    case "daily":
                        nextDate = Calendar.current.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
                    case "weekly":
                        nextDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: nextDate) ?? nextDate
                    case "monthly":
                        nextDate = Calendar.current.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
                    default:
                        break
                    }
                }
                
                // 更新提醒的日期
                reminder.date = nextDate
                try? modelContext.save()
            }
        }
    }
    
    // 添加删除提醒方法
    func deleteReminder(_ reminder: Reminder) {
        modelContext.delete(reminder)
        try? modelContext.save()
    }
    
    // 修复所有提醒的重复类型
    func fixAllReminderTypes() {
        do {
            // 创建查询描述符
            var descriptor = FetchDescriptor<Reminder>()
            
            // 执行查询获取所有提醒
            let allReminders = try modelContext.fetch(descriptor)
            
            print("修复所有提醒重复类型：共 \(allReminders.count) 个提醒")
            
            // 遍历所有提醒，检查和修复重复类型
            for reminder in allReminders {
                detectAndFixRepeatType(reminder)
            }
            
            // 保存更改
            try modelContext.save()
            print("所有提醒重复类型修复完成")
            
        } catch {
            print("修复提醒重复类型时出错: \(error)")
        }
    }
} 