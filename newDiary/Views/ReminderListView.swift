import SwiftUI
import SwiftData
import Combine

// 提醒事項列表視圖
struct ReminderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 移除過濾器，顯示所有提醒（包括已完成的）
    @Query(sort: \Reminder.date)
    private var allReminders: [Reminder]
    
    // 添加顯示已完成提醒的控制開關 - 默認值改為true，即默認顯示所有提醒
    @State private var showCompleted: Bool = true
    
    @State private var showingAddReminder = false
    @State private var reminderToEdit: Reminder? = nil
    
    // 添加一個刷新觸發器
    @State private var refreshTrigger: Bool = false
    // 添加一個計時器發佈器
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // 計算屬性：根據showCompleted狀態過濾提醒
    private var remindersToShow: [Reminder] {
        if showCompleted {
            return allReminders
        } else {
            return allReminders.filter { !$0.isCompleted }
        }
    }
    
    // 獲取提醒類型的顏色
    private func getColorForReminderType(_ repeatType: String) -> Color {
        switch repeatType {
        case "daily":
            return .yellow
        case "weekly":
            return .green
        case "monthly":
            return .red
        default:
            return .white  // 無重復使用白色
        }
    }
    
    var body: some View {
        #if os(iOS)
        // iOS版本使用NavigationView和swipeActions
        iOSContent
            .onReceive(timer) { _ in
                // 每秒檢查一次數據更新
                modelContext.processPendingChanges()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshReminders"))) { _ in
                // 當收到刷新提醒的通知時，刷新提醒列表
                refreshReminders()
            }
        #else
        // macOS版本使用NavigationStack和contextMenu
        macOSContent
            .onReceive(timer) { _ in
                // 每秒檢查一次數據更新
                modelContext.processPendingChanges()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshReminders"))) { _ in
                // 當收到刷新提醒的通知時，刷新提醒列表
                refreshReminders()
            }
        #endif
    }
    
    // iOS版本的內容
    private var iOSContent: some View {
        NavigationView {
            List {
                // 添加切換顯示已完成提醒的開關
                Section {
                    Toggle("顯示已完成提醒", isOn: $showCompleted)
                }
                
                Section {
                    listContent
                }
            }
            .navigationTitle("提醒事項")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddReminder = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView(
                    reminderDate: Date(),
                    isCompleted: false,
                    onSave: { reminderDate, reminderTitle, isCompleted in
                        // 創建提醒時檢查標題是否包含"每日"/"每週"/"每月"關鍵詞
                        var repeatType = "none"
                        let lowercaseTitle = reminderTitle.lowercased()
                        
                        if lowercaseTitle.contains("everyday") || lowercaseTitle.contains("每日") || lowercaseTitle.contains("daily") {
                            repeatType = "daily"
                        } else if lowercaseTitle.contains("每週") || lowercaseTitle.contains("weekly") || lowercaseTitle.contains("每周") {
                            repeatType = "weekly"
                        } else if lowercaseTitle.contains("每月") || lowercaseTitle.contains("monthly") {
                            repeatType = "monthly"
                        }
                        
                        // 使用檢測到的重復類型創建提醒
                        let newReminder = Reminder(
                            title: reminderTitle,
                            date: reminderDate,
                            isCompleted: isCompleted,
                            repeatType: repeatType
                        )
                        
                        modelContext.insert(newReminder)
                        
                        // 額外使用ReminderService檢測並修復重復類型（雙重保險）
                        let reminderService = ReminderService(modelContext: modelContext)
                        reminderService.detectAndFixRepeatType(newReminder)
                        
                        try? modelContext.save()
                        
                        // 打印調試信息
                        print("已創建提醒: \(reminderTitle), 重復類型: \(repeatType)")
                        
                        refreshReminders()
                    }
                )
                .onDisappear {
                    refreshReminders()
                }
            }
            .sheet(item: $reminderToEdit) { reminder in
                AddReminderView(
                    reminderTitle: reminder.title,
                    reminderDate: reminder.date,
                    isCompleted: reminder.isCompleted,
                    onSave: { reminderDate, reminderTitle, isCompleted in
                        reminder.title = reminderTitle
                        reminder.date = reminderDate
                        reminder.isCompleted = isCompleted
                        
                        // 使用ReminderService檢測並修復重復類型
                        let reminderService = ReminderService(modelContext: modelContext)
                        reminderService.detectAndFixRepeatType(reminder)
                        
                        try? modelContext.save()
                        refreshReminders()
                        reminderToEdit = nil
                    }
                )
                .onDisappear {
                    refreshReminders()
                }
            }
        }
    }
    
    // macOS版本的內容
    private var macOSContent: some View {
        NavigationStack {
            VStack {
                // 添加切換顯示已完成提醒的開關
                Toggle("顯示已完成提醒", isOn: $showCompleted)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                List {
                    listContent
                }
            }
            .navigationTitle("提醒事項")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddReminder = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .help("添加新提醒")
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                    .help("關閉視窗")
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView(
                    reminderDate: Date(),
                    isCompleted: false,
                    onSave: { reminderDate, reminderTitle, isCompleted in
                        // 創建提醒時檢查標題是否包含"每日"/"每週"/"每月"關鍵詞
                        var repeatType = "none"
                        let lowercaseTitle = reminderTitle.lowercased()
                        
                        if lowercaseTitle.contains("everyday") || lowercaseTitle.contains("每日") || lowercaseTitle.contains("daily") {
                            repeatType = "daily"
                        } else if lowercaseTitle.contains("每週") || lowercaseTitle.contains("weekly") || lowercaseTitle.contains("每周") {
                            repeatType = "weekly"
                        } else if lowercaseTitle.contains("每月") || lowercaseTitle.contains("monthly") {
                            repeatType = "monthly"
                        }
                        
                        // 使用檢測到的重復類型創建提醒
                        let newReminder = Reminder(
                            title: reminderTitle,
                            date: reminderDate,
                            isCompleted: isCompleted,
                            repeatType: repeatType
                        )
                        
                        modelContext.insert(newReminder)
                        
                        // 額外使用ReminderService檢測並修復重復類型（雙重保險）
                        let reminderService = ReminderService(modelContext: modelContext)
                        reminderService.detectAndFixRepeatType(newReminder)
                        
                        try? modelContext.save()
                        
                        // 打印調試信息
                        print("已創建提醒: \(reminderTitle), 重復類型: \(repeatType)")
                        
                        refreshReminders()
                    }
                )
                .frame(width: 300, height: 300)
                .onDisappear {
                    refreshReminders()
                }
            }
            .sheet(item: $reminderToEdit) { reminder in
                AddReminderView(
                    reminderTitle: reminder.title,
                    reminderDate: reminder.date,
                    isCompleted: reminder.isCompleted,
                    onSave: { reminderDate, reminderTitle, isCompleted in
                        reminder.title = reminderTitle
                        reminder.date = reminderDate
                        reminder.isCompleted = isCompleted
                        
                        // 使用ReminderService檢測並修復重復類型
                        let reminderService = ReminderService(modelContext: modelContext)
                        reminderService.detectAndFixRepeatType(reminder)
                        
                        try? modelContext.save()
                        refreshReminders()
                        reminderToEdit = nil
                    }
                )
                .frame(width: 300, height: 300)
                .onDisappear {
                    refreshReminders()
                }
            }
        }
    }
    
    // 共用的列表內容
    private var listContent: some View {
        Group {
            if remindersToShow.isEmpty {
                ContentUnavailableView {
                    Label("無提醒事項", systemImage: "bell.slash")
                } description: {
                    Text("點擊右上角加號添加提醒")
                }
            } else {
                ForEach(remindersToShow) { reminder in
                    ReminderRowView(reminder: reminder)
                        .opacity(reminder.isCompleted ? 0.6 : 1.0) // 已完成的提醒透明度降低
                        .padding(.vertical, 2)
                        .listRowBackground(
                            getColorForReminderType(reminder.repeatType)
                                .opacity(0.25) // 使用更高透明度的背景色
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        #if os(iOS)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteReminder(reminder)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                            
                            Button {
                                reminderToEdit = reminder
                            } label: {
                                Label("編輯", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading) {
                            if reminder.isCompleted {
                                Button {
                                    uncompleteReminder(reminder)
                                } label: {
                                    Label("取消完成", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.orange)
                            } else {
                                Button {
                                    completeReminder(reminder)
                                } label: {
                                    Label("完成", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                        #endif
                        .contextMenu {
                            Button(action: {
                                reminderToEdit = reminder
                            }) {
                                Label("編輯", systemImage: "pencil")
                            }
                            
                            if reminder.isCompleted {
                                Button(action: {
                                    uncompleteReminder(reminder)
                                }) {
                                    Label("取消完成標記", systemImage: "arrow.uturn.backward")
                                }
                            } else {
                                Button(action: {
                                    completeReminder(reminder)
                                }) {
                                    Label("標記為完成", systemImage: "checkmark")
                                }
                            }
                            
                            Divider()
                            
                            Button(role: .destructive, action: {
                                deleteReminder(reminder)
                            }) {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
    
    private func deleteReminder(_ reminder: Reminder) {
        let reminderService = ReminderService(modelContext: modelContext)
        reminderService.deleteReminder(reminder)
        
        // 刷新提醒列表
        refreshReminders()
    }
    
    private func completeReminder(_ reminder: Reminder) {
        let reminderService = ReminderService(modelContext: modelContext)
        reminderService.completeReminder(reminder)
        
        // 刷新提醒列表
        refreshReminders()
    }
    
    // 添加取消完成的方法
    private func uncompleteReminder(_ reminder: Reminder) {
        reminder.isCompleted = false
        try? modelContext.save()
        
        // 刷新提醒列表
        refreshReminders()
    }
    
    // 添加刷新提醒列表的方法
    private func refreshReminders() {
        // 延遲執行，確保之前的操作已完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 刷新提醒列表的數據
            // 因為SwiftData會自動跟蹤變更，我們只需要確保UI更新
            refreshTrigger.toggle()
            
            // 記錄刷新時間，方便調試
            print("提醒列表已刷新：\(Date())")
        }
    }
}

#Preview {
    ReminderListView()
        .modelContainer(for: Reminder.self)
}
