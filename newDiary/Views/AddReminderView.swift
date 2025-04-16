import SwiftUI
import SwiftData

struct AddReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var isCompleted: Bool = false
    @State private var selectedRepeatType: ReminderRepeatType = .none
    
    // 新增回调函数
    private var onSaveCallback: ((Date, String, Bool) -> Void)?
    private var isEditing: Bool = false
    
    // 旧的初始化方法 - 保留向后兼容性
    init(reminder: Reminder? = nil) {
        self.isEditing = reminder != nil
        
        if let reminder = reminder {
            _title = State(initialValue: reminder.title)
            _date = State(initialValue: reminder.date)
            _isCompleted = State(initialValue: reminder.isCompleted)
            
            if let repeatType = ReminderRepeatType(rawValue: reminder.repeatType) {
                _selectedRepeatType = State(initialValue: repeatType)
            }
        }
    }
    
    // 新增初始化方法 - 用于创建新提醒
    init(
        reminderDate: Date = Date(),
        isCompleted: Bool = false,
        onSave: @escaping (Date, String, Bool) -> Void
    ) {
        self._date = State(initialValue: reminderDate)
        self._isCompleted = State(initialValue: isCompleted)
        self.onSaveCallback = onSave
        self.isEditing = false
    }
    
    // 新增初始化方法 - 用于编辑现有提醒
    init(
        reminderTitle: String,
        reminderDate: Date,
        isCompleted: Bool,
        onSave: @escaping (Date, String, Bool) -> Void
    ) {
        self._title = State(initialValue: reminderTitle)
        self._date = State(initialValue: reminderDate)
        self._isCompleted = State(initialValue: isCompleted)
        self.onSaveCallback = onSave
        self.isEditing = true
    }
    
    var body: some View {
        #if os(iOS)
        // iOS版本
        NavigationView {
            formContent
                .navigationTitle(isEditing ? "编辑提醒" : "新增提醒")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isEditing ? "保存" : "新增") {
                            if let onSaveCallback = onSaveCallback {
                                onSaveCallback(date, title, isCompleted)
                            } else {
                                isEditing ? updateReminder() : addReminder()
                            }
                            dismiss()
                        }
                        .disabled(title.isEmpty)
                    }
                }
        }
        #else
        // macOS版本
        VStack {
            Text(isEditing ? "编辑提醒" : "新增提醒")
                .font(.headline)
                .padding(.top)
            
            formContent
                .padding()
            
            HStack {
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button(isEditing ? "保存" : "新增") {
                    if let onSaveCallback = onSaveCallback {
                        onSaveCallback(date, title, isCompleted)
                    } else {
                        isEditing ? updateReminder() : addReminder()
                    }
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(title.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 400, height: 450)
        #endif
    }
    
    // 共用的表单内容
    private var formContent: some View {
        Form {
            Section(header: Text("提醒内容")) {
                TextField("标题", text: $title)
                    .onChange(of: title) { oldValue, newValue in
                        // 根据标题智能判断重复类型
                        detectRepeatTypeFromTitle(newValue)
                    }
                
                Toggle("已完成", isOn: $isCompleted)
            }
            
            Section(header: Text("时间")) {
                DatePicker("日期和时间", selection: $date)
                    .datePickerStyle(.compact)
            }
            
            Section(header: Text("重复")) {
                Picker("重复类型", selection: $selectedRepeatType) {
                    ForEach(ReminderRepeatType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // 提示信息
            if selectedRepeatType != .none {
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text(getRepeatDescription())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func getRepeatDescription() -> String {
        switch selectedRepeatType {
        case .daily:
            return "此提醒将每天触发一次"
        case .weekly:
            let weekday = Calendar.current.component(.weekday, from: date)
            let weekdaySymbol = Calendar.current.weekdaySymbols[weekday - 1]
            return "此提醒将每周\(weekdaySymbol)触发一次"
        case .monthly:
            let day = Calendar.current.component(.day, from: date)
            return "此提醒将每月\(day)日触发一次"
        case .none:
            return "此提醒仅在指定日期触发一次"
        }
    }
    
    // 根据标题智能判断重复类型
    private func detectRepeatTypeFromTitle(_ title: String) {
        let lowercaseTitle = title.lowercased()
        
        if lowercaseTitle.contains("everyday") || lowercaseTitle.contains("每日") || lowercaseTitle.contains("daily") {
            selectedRepeatType = .daily
        } else if lowercaseTitle.contains("每周") || lowercaseTitle.contains("weekly") || lowercaseTitle.contains("每周") {
            selectedRepeatType = .weekly
        } else if lowercaseTitle.contains("每月") || lowercaseTitle.contains("monthly") {
            selectedRepeatType = .monthly
        }
    }
    
    private func addReminder() {
        // 检查标题是否包含重复类型关键词，如果包含则更新selectedRepeatType
        detectRepeatTypeFromTitle(title)
        
        let newReminder = Reminder(
            title: title,
            date: date,
            isCompleted: isCompleted,
            repeatType: selectedRepeatType.rawValue
        )
        
        // 记录日志，用于调试
        print("正在创建提醒: \(title), 日期: \(date), 类型: \(selectedRepeatType.rawValue)")
        
        modelContext.insert(newReminder)
        
        // 使用ReminderService再次检测并修复重复类型（双重保险）
        let reminderService = ReminderService(modelContext: modelContext)
        reminderService.detectAndFixRepeatType(newReminder)
        
        try? modelContext.save()
    }
    
    private func updateReminder() {
        // 尝试通过查询找到匹配的提醒，而不是使用不存在的registeredObjects
        do {
            var descriptor = FetchDescriptor<Reminder>()
            descriptor.predicate = #Predicate<Reminder> { reminder in
                reminder.title == title
            }
            
            if let reminder = try modelContext.fetch(descriptor).first {
                reminder.title = title
                reminder.date = date
                reminder.repeatType = selectedRepeatType.rawValue
                reminder.isCompleted = isCompleted
                
                // 记录日志，用于调试
                print("正在更新提醒: \(title), 日期: \(date), 类型: \(selectedRepeatType.rawValue)")
                
                try? modelContext.save()
            }
        } catch {
            print("更新提醒时出错: \(error)")
        }
    }
}

#Preview {
    AddReminderView()
        .modelContainer(for: Reminder.self)
}
