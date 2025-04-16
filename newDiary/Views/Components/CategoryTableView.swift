import SwiftUI
import SwiftData

// 不再需要 Color 擴展，因為它已經在 Color+Extensions.swift 中定義

struct CategoryTableView: View {
    let type: DiaryEntryType
    let entries: [CategoryEntry]
    let diary: DiaryEntry
    let onAdd: () -> Void
    let onDelete: (IndexSet) -> Void
    let onEdit: (CategoryEntry) -> Void
    
    // 在初始化時為每種類型設置不同的UserDefaults鍵
    private let nameColumnWidthKey: String
    private let categoryColumnWidthKey: String
    private let numberColumnWidthKey: String
    private let notesColumnWidthKey: String
    
    // 使用UserDefaults直接管理列寬
    @State private var nameColumnWidth: Double
    @State private var categoryColumnWidth: Double
    @State private var numberColumnWidth: Double
    @State private var notesColumnWidth: Double
    
    // 拖動狀態
    @State private var isDraggingName = false
    @State private var isDraggingCategory = false
    @State private var isDraggingNumber = false
    
    init(type: DiaryEntryType, entries: [CategoryEntry], diary: DiaryEntry, onAdd: @escaping () -> Void, onDelete: @escaping (IndexSet) -> Void, onEdit: @escaping (CategoryEntry) -> Void) {
        self.type = type
        self.entries = entries
        self.diary = diary
        self.onAdd = onAdd
        self.onDelete = onDelete
        self.onEdit = onEdit
        
        // 為每種類型創建唯一的鍵
        self.nameColumnWidthKey = "nameColumnWidth_\(type.rawValue)"
        self.categoryColumnWidthKey = "categoryColumnWidth_\(type.rawValue)"
        self.numberColumnWidthKey = "numberColumnWidth_\(type.rawValue)"
        self.notesColumnWidthKey = "notesColumnWidth_\(type.rawValue)"
        
        // 從UserDefaults加載列寬，如果沒有則使用默認值
        self._nameColumnWidth = State(initialValue: UserDefaults.standard.double(forKey: nameColumnWidthKey).isZero ? 150 : UserDefaults.standard.double(forKey: nameColumnWidthKey))
        self._categoryColumnWidth = State(initialValue: UserDefaults.standard.double(forKey: categoryColumnWidthKey).isZero ? 150 : UserDefaults.standard.double(forKey: categoryColumnWidthKey))
        self._numberColumnWidth = State(initialValue: UserDefaults.standard.double(forKey: numberColumnWidthKey).isZero ? 120 : UserDefaults.standard.double(forKey: numberColumnWidthKey))
        self._notesColumnWidth = State(initialValue: UserDefaults.standard.double(forKey: notesColumnWidthKey).isZero ? 200 : UserDefaults.standard.double(forKey: notesColumnWidthKey))
    }
    
    // 保存列寬到UserDefaults
    private func saveColumnWidths() {
        UserDefaults.standard.set(nameColumnWidth, forKey: nameColumnWidthKey)
        UserDefaults.standard.set(categoryColumnWidth, forKey: categoryColumnWidthKey)
        UserDefaults.standard.set(numberColumnWidth, forKey: numberColumnWidthKey)
        UserDefaults.standard.set(notesColumnWidth, forKey: notesColumnWidthKey)
    }
    
    // 添加將分鐘數格式化為h:mm格式的函數
    private func formatMinutesToTimeString(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%d:%02d", hours, mins)
    }
    
    // 添加金額格式化函數
    private func formatAmount(_ amount: Double) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 0
        
        if let formattedNumber = numberFormatter.string(from: NSNumber(value: amount)) {
            return "NT$\(formattedNumber)"
        }
        return "NT$\(Int(amount))"
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
    
    // 分隔線視圖
    struct ColumnDivider: View {
        var isDragging: Bool
        var onDrag: ((DragGesture.Value) -> Void)?
        var onDragEnd: (() -> Void)?
        
        var body: some View {
            Rectangle()
                .fill(isDragging ? Color.blue : Color.gray.opacity(0.5))
                .frame(width: isDragging ? 2 : 1)
                .padding(.vertical, 5)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            onDrag?(value)
                        }
                        .onEnded { _ in
                            onDragEnd?()
                        }
                )
                .onHover { _ in
                    NSCursor.resizeLeftRight.push()
                }
                .onDisappear {
                    NSCursor.pop()
                }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 標題區域
            HStack {
                // 圖標和標題
                HStack(spacing: 8) {
                    Image(systemName: type.icon)
                        .font(.system(size: titleFontSize))
                        .foregroundColor(typeColor)
                    
                    Text(type.localizedName)
                        .font(.system(size: titleFontSize))
                        .foregroundColor(Color.fromString(titleFontColor))
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // 新增按鈕
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: titleFontSize))
                        .foregroundColor(typeColor)
                }
                .buttonStyle(.plain)
                .onHover { _ in
                    NSCursor.pointingHand.push()
                }
                .onDisappear {
                    NSCursor.pop()
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(typeColor.opacity(0.1))
            
            // 內容區域
            if entries.isEmpty {
                // 空狀態顯示
                VStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("尚無記錄")
                        .font(.system(size: contentFontSize))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color(.textBackgroundColor).opacity(0.2))
            } else {
                VStack(spacing: 0) {
                    // 表格標題行
                    HStack(spacing: 0) {
                        Text(nameLabel)
                            .frame(width: nameColumnWidth, alignment: .leading)
                            .padding(.leading, 15)
                            
                        ColumnDivider(
                            isDragging: isDraggingName,
                            onDrag: { value in
                                isDraggingName = true
                                let newWidth = nameColumnWidth + value.translation.width
                                nameColumnWidth = max(80, min(300, newWidth))
                                saveColumnWidths()
                            },
                            onDragEnd: {
                                isDraggingName = false
                                saveColumnWidths()
                            }
                        )
                        
                        Text(categoryLabel)
                            .frame(width: categoryColumnWidth, alignment: .leading)
                            .padding(.leading, 5)
                            
                        ColumnDivider(
                            isDragging: isDraggingCategory,
                            onDrag: { value in
                                isDraggingCategory = true
                                let newWidth = categoryColumnWidth + value.translation.width
                                categoryColumnWidth = max(80, min(300, newWidth))
                                saveColumnWidths()
                            },
                            onDragEnd: {
                                isDraggingCategory = false
                                saveColumnWidths()
                            }
                        )
                        
                        Text(numberLabel)
                            .frame(width: numberColumnWidth, alignment: .trailing)
                            .padding(.leading, 5)
                            
                        ColumnDivider(
                            isDragging: isDraggingNumber,
                            onDrag: { value in
                                isDraggingNumber = true
                                let newWidth = numberColumnWidth + value.translation.width
                                numberColumnWidth = max(80, min(200, newWidth))
                                saveColumnWidths()
                            },
                            onDragEnd: {
                                isDraggingNumber = false
                                saveColumnWidths()
                            }
                        )
                        
                        Text("備注")
                            .frame(width: notesColumnWidth, alignment: .leading)
                            .padding(.leading, 5)
                            
                        Spacer()
                        
                        Text("操作")
                            .frame(width: 100, alignment: .center)
                    }
                    .font(.system(size: contentFontSize * 0.9))
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
                    .background(Color(.textBackgroundColor).opacity(0.3))
                    
                    // 表格內容
                    ForEach(entries) { entry in
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Text(entry.name)
                                    .frame(width: nameColumnWidth, alignment: .leading)
                                    .padding(.leading, 15)
                                
                                ColumnDivider(isDragging: false, onDrag: nil, onDragEnd: nil)
                                
                                Text(entry.category)
                                    .frame(width: categoryColumnWidth, alignment: .leading)
                                    .padding(.leading, 5)
                                
                                ColumnDivider(isDragging: false, onDrag: nil, onDragEnd: nil)
                                
                                if type == .expense {
                                    Text(formatAmount(entry.number))
                                        .frame(width: numberColumnWidth, alignment: .trailing)
                                        .monospacedDigit()
                                        .padding(.leading, 5)
                                } else {
                                    Text(formatMinutesToTimeString(Int(entry.number)))
                                        .frame(width: numberColumnWidth, alignment: .trailing)
                                        .monospacedDigit()
                                        .padding(.leading, 5)
                                }
                                
                                ColumnDivider(isDragging: false, onDrag: nil, onDragEnd: nil)
                                
                                Text(entry.notes)
                                    .frame(width: notesColumnWidth, alignment: .leading)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 5)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                HStack(spacing: 16) {
                                    Button(action: { onEdit(entry) }) {
                                        Image(systemName: "pencil")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { _ in
                                        NSCursor.pointingHand.push()
                                    }
                                    .onDisappear {
                                        NSCursor.pop()
                                    }
                                    
                                    Button(action: {
                                        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                                            onDelete(IndexSet([index]))
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .onHover { _ in
                                        NSCursor.pointingHand.push()
                                    }
                                    .onDisappear {
                                        NSCursor.pop()
                                    }
                                }
                                .frame(width: 100)
                            }
                            .font(.system(size: contentFontSize))
                            .foregroundColor(Color.fromString(contentFontColor))
                            .padding(.vertical, 10)
                            
                            Divider()
                                .padding(.horizontal, 10)
                        }
                    }
                }
            }
            
            // 合計區域
            HStack {
                // 月合計（左側）
                HStack(spacing: 8) {
                    Text("本月合計:")
                        .foregroundColor(.secondary)
                    if type == .expense {
                        Text(formatAmount(monthlyTotal))
                            .monospacedDigit()
                            .foregroundColor(monthlyTotal > monthlyExpenseLimit ? .red : .green)
                    } else {
                        Text(formatMinutesToTimeString(Int(monthlyTotal)))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 日合計（右側）
                HStack(spacing: 8) {
                    Text("今日合計:")
                        .foregroundColor(.secondary)
                    if type == .expense {
                        Text(formatAmount(total))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    } else {
                        let isUnderGoal = total < getDailyGoal()
                        Text(formatMinutesToTimeString(Int(total)))
                            .monospacedDigit()
                            .foregroundColor(isUnderGoal ? .red : .green)
                    }
                }
            }
            .font(.system(size: contentFontSize * 0.9))
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(Color(.textBackgroundColor).opacity(0.2))
        }
        .background(Color(.textBackgroundColor).opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(typeColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .onDisappear {
            saveColumnWidths()
        }
    }
    
    var typeColor: Color {
        switch type {
        case .expense: return .green
        case .exercise: return .orange
        case .sleep: return .purple
        case .work: return .red
        case .relationship: return .pink
        case .study: return .blue
        }
    }
    
    // 根據類型獲取每日目標
    private func getDailyGoal() -> Double {
        switch type {
        case .expense:
            return 0  // 支出使用月度目標
        case .exercise:
            return dailyExerciseGoal
        case .sleep:
            return dailySleepGoal
        case .work:
            return dailyWorkGoal
        case .relationship:
            return dailyRelationshipGoal
        case .study:
            return dailyStudyGoal
        }
    }
}
