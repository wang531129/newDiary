import SwiftUI
import SwiftData
import AppKit

// 添加擴展到文件頂級範圍
extension NSTextView {
    func inFocus() -> Bool {
        self.window?.firstResponder == self
    }
}

// 添加自定義的TabView樣式
struct CustomTabStyle: View {
    let isSelected: Bool
    let color: Color
    let label: () -> AnyView
    
    init(isSelected: Bool, color: Color, @ViewBuilder label: @escaping () -> some View) {
        self.isSelected = isSelected
        self.color = color
        self.label = { AnyView(label()) }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            label()
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                gradient: Gradient(colors: [color.opacity(0.9), color]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        } else {
                            Color.clear
                        }
                    }
                )
                .cornerRadius(8)
                .shadow(color: isSelected ? color.opacity(0.5) : Color.clear, radius: 2, x: 0, y: 1)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            
            Rectangle()
                .fill(isSelected ? color : Color.clear)
                .frame(height: 3)
                .padding(.horizontal, 4)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .padding(.vertical, 2)
    }
}

/// 日記詳細內容視圖
public struct DiaryDetailView: View {
    @Bindable var diary: DiaryEntry
    @Binding var selectedTab: String?
    
    @Environment(\.modelContext) private var modelContext
    @State private var showingSheet = false
    @State private var currentCategory: DiaryEntryType = .expense
    @State private var editingEntry: CategoryEntry? = nil
    @State private var selectedWeather: String
    @State private var isOnline = true
    @State private var isLoading = false
    @State private var thoughts: String
    
    // 警告相關狀態
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    // 提醒相關狀態
    @State private var showingReminderDialog = false
    @State private var reminderDate = Date()
    @State private var reminderTime = Date()
    @State private var reminderTitle = ""
    @State private var selectedRepeatType: ReminderRepeatType = .none
    
    // 修改狀態變量
    @State private var showingQuickMenu = false
    @State private var lastAtPosition: Int = 0
    @FocusState private var isTextEditorFocused: Bool
    
    // 使用者偏好設置
    @AppStorage("titleFontSize") private var titleFontSize: Double = 22
    @AppStorage("contentFontSize") private var contentFontSize: Double = 16
    @AppStorage("titleFontColor") private var titleFontColor: String = "Green"
    @AppStorage("contentFontColor") private var contentFontColor: String = "White"
    @AppStorage("weatherApiKey") private var weatherApiKey: String = ""
    
    // 天氣服務
    private let weatherService: WeatherService?
    
    // Add date formatter
    private let customDateFormatter = DateFormatter()
    
    // 當前日期是今天嗎？
    private var isToday: Bool {
        Calendar.current.isDateInToday(diary.date)
    }
    
    // 標籤相關
    @State private var showingTagMenu = false
    
    // 標籤分類結構
    enum TagCategory: String, CaseIterable {
        case emotions = "情緒"
        case activities = "活動"
        case lifeAreas = "生活領域"
        case thinking = "思考"
        case time = "時間"
        case importance = "重要性"
        case events = "特殊事件"
        case health = "健康"
        
        var tags: [DiaryTag] {
            switch self {
            case .emotions:
                return [
                    DiaryTag(emoji: "😄", name: "開心"),
                    DiaryTag(emoji: "😔", name: "憂鬱"),
                    DiaryTag(emoji: "😰", name: "焦慮"),
                    DiaryTag(emoji: "😌", name: "滿足"),
                    DiaryTag(emoji: "🤩", name: "期待")
                ]
            case .activities:
                return [
                    DiaryTag(emoji: "💼", name: "工作"),
                    DiaryTag(emoji: "📚", name: "學習"),
                    DiaryTag(emoji: "🏃", name: "運動"),
                    DiaryTag(emoji: "🎮", name: "休閒"),
                    DiaryTag(emoji: "👥", name: "社交")
                ]
            case .lifeAreas:
                return [
                    DiaryTag(emoji: "🏠", name: "家庭"),
                    DiaryTag(emoji: "🏥", name: "健康"),
                    DiaryTag(emoji: "💰", name: "財務"),
                    DiaryTag(emoji: "❤️", name: "愛情"),
                    DiaryTag(emoji: "🤝", name: "友誼")
                ]
            case .thinking:
                return [
                    DiaryTag(emoji: "💭", name: "感悟"),
                    DiaryTag(emoji: "🎯", name: "目標"),
                    DiaryTag(emoji: "📝", name: "計劃"),
                    DiaryTag(emoji: "🔄", name: "回顧"),
                    DiaryTag(emoji: "❓", name: "疑問")
                ]
            case .time:
                return [
                    DiaryTag(emoji: "🌅", name: "早晨"),
                    DiaryTag(emoji: "☀️", name: "中午"),
                    DiaryTag(emoji: "🌆", name: "傍晚"),
                    DiaryTag(emoji: "🌙", name: "夜晚"),
                    DiaryTag(emoji: "📅", name: "週末")
                ]
            case .importance:
                return [
                    DiaryTag(emoji: "🔴", name: "重要"),
                    DiaryTag(emoji: "🟡", name: "一般"),
                    DiaryTag(emoji: "🟢", name: "輕微"),
                    DiaryTag(emoji: "⚪️", name: "無")
                ]
            case .events:
                return [
                    DiaryTag(emoji: "🎂", name: "紀念"),
                    DiaryTag(emoji: "✈️", name: "旅行"),
                    DiaryTag(emoji: "🎉", name: "節日"),
                    DiaryTag(emoji: "🏆", name: "里程碑"),
                    DiaryTag(emoji: "😲", name: "意外")
                ]
            case .health:
                return [
                    DiaryTag(emoji: "🍲", name: "飲食"),
                    DiaryTag(emoji: "😴", name: "睡眠"),
                    DiaryTag(emoji: "💪", name: "運動"),
                    DiaryTag(emoji: "🤒", name: "症狀"),
                    DiaryTag(emoji: "🧠", name: "心理")
                ]
            case .time:
                return [
                    DiaryTag(emoji: "🌅", name: "早晨"),
                    DiaryTag(emoji: "☀️", name: "白天"),
                    DiaryTag(emoji: "🌙", name: "夜晚"),
                    DiaryTag(emoji: "📅", name: "週末")
                ]
            }
        }
    }
    
    // 標籤數據結構
    struct DiaryTag: Identifiable {
        let id = UUID()
        let emoji: String
        let name: String
        
        var formatted: String {
            return "\(emoji)\(name): "
        }
    }
    
    // 所有標籤（由各分類整合）
    var allTags: [DiaryTag] {
        TagCategory.allCases.flatMap { $0.tags }
    }
    
    // 初始化方法
    public init(diary: DiaryEntry, selectedTab: Binding<String?>) {
        self._diary = Bindable(wrappedValue: diary)
        self._selectedTab = selectedTab
        
        // Initialize values from the diary
        self.selectedWeather = diary.weather.rawValue
        self.thoughts = diary.thoughts
        
        // Check for custom date format from user preferences
        if let formatString = UserDefaults.standard.string(forKey: "dateFormatString") {
            customDateFormatter.dateFormat = formatString
        }
        
        // Initialize isOnline state based on whether the diary is for today
        let isForToday = Calendar.current.isDateInToday(diary.date)
        self._isOnline = State(initialValue: isForToday)
        
        // Setup weather service
        // Try to get the API key from UserDefaults
        if let apiKey = UserDefaults.standard.string(forKey: "weatherApiKey"), !apiKey.isEmpty {
            print("Initializing WeatherService with API key")
            self.weatherService = WeatherService(apiKey: apiKey)
        } else {
            print("No API key found, initializing WeatherService with empty key for fallback mode")
            // Still create a WeatherService, but it will use the fallback implementation
            self.weatherService = WeatherService()
        }
    }
    
    // 插入標籤到文本
    private func insertTag(_ tag: DiaryTag) {
        // 在當前文本末尾添加新行和標籤
        thoughts += "\n\(tag.formatted)"
        diary.thoughts = thoughts
        saveContext()
    }
    
    // 添加待辦事項
    private func addTodoItem() {
        // 獲取當前文本和光標位置
        guard let textView = NSApplication.shared.keyWindow?.firstResponder as? NSTextView else {
            // 如果獲取不到光標位置，就在末尾添加
            let newTodo = "🔳 "
            thoughts += thoughts.isEmpty ? newTodo : "\n\(newTodo)"
            diary.thoughts = thoughts
            saveContext()
            return
        }
        
        let selectedRange = textView.selectedRange()
        let text = thoughts as NSString
        
        // 獲取光標所在行的範圍
        let lineRange = text.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let line = text.substring(with: lineRange)
        
        // 準備新的文本
        var newText: String
        var cursorAdjustment = 0
        
        if line.hasPrefix("🔳") {
            // 如果已經有🔳，切換為✅，保留後面的內容
            let remainingText = String(line.dropFirst(1))  // 只刪除表情符號
            newText = "✅\(remainingText)"
        } else if line.hasPrefix("✅") {
            // 如果已經有✅，切換為🔳，保留後面的內容
            let remainingText = String(line.dropFirst(1))  // 只刪除表情符號
            newText = "🔳\(remainingText)"
        } else {
            // 如果沒有標記，在行首添加🔳，保留整行內容
            newText = "🔳 \(line)"
            cursorAdjustment = 2  // 調整光標位置以適應新添加的"🔳 "
        }
        
        // 保存當前光標位置相對於行首的偏移量
        let cursorOffsetInLine = selectedRange.location - lineRange.location
        
        // 替換當前行
        let newRange = NSRange(location: lineRange.location, length: lineRange.length)
        textView.shouldChangeText(in: newRange, replacementString: newText)
        textView.replaceCharacters(in: newRange, with: newText)
        
        // 更新thoughts並保存
        thoughts = textView.string
        diary.thoughts = thoughts
        saveContext()
        
        // 設置新的光標位置
        let newCursorLocation = lineRange.location + cursorOffsetInLine + cursorAdjustment
        textView.setSelectedRange(NSRange(location: newCursorLocation, length: 0))
    }
    
    // 檢查是否是待辦事項
    private func isTodoItem(_ text: String) -> Bool {
        return text.hasPrefix("🔳 ") || text.hasPrefix("✅ ")
    }
    
    // 獲取所有行
    private var lines: [String] {
        thoughts.components(separatedBy: .newlines)
    }
    
    // 記事部分的視圖
    private var thoughtsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("記事")
                    .font(.system(size: titleFontSize))
                    .foregroundColor(Color.fromString(titleFontColor))
                    .fontWeight(.bold)
                
                Button(action: { showReminderDialog() }) {
                    Text("⏰")
                        .font(.system(size: titleFontSize))
                        .foregroundColor(Color.fromString(titleFontColor))
                }
                .buttonStyle(.borderless)
                .help("新增日期和時間提醒")
                .sheet(isPresented: $showingReminderDialog) {
                    ReminderDialog(
                        isPresented: $showingReminderDialog,
                        date: $reminderDate,
                        time: $reminderTime,
                        title: $reminderTitle,
                        onConfirm: addReminder
                    )
                }
                
                // 添加模板按鈕
                Button(action: useTemplate) {
                    HStack {
                        Text("📝")
                            .font(.system(size: titleFontSize))
                            .foregroundColor(Color.fromString(titleFontColor))
                        Text("模板")
                            .font(.system(size: titleFontSize * 0.7))
                            .foregroundColor(Color.fromString(titleFontColor))
                    }
                }
                .buttonStyle(.borderless)
                .help("使用記事模板")
                
                // 添加標籤按鈕
                Menu {
                    ForEach(TagCategory.allCases, id: \.self) { category in
                        Section(header: Text(category.rawValue)) {
                            ForEach(category.tags) { tag in
                                Button(action: { insertTag(tag) }) {
                                    Text("\(tag.emoji) \(tag.name)")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("🏷️")
                            .font(.system(size: titleFontSize))
                            .foregroundColor(Color.fromString(titleFontColor))
                        Text("標籤")
                            .font(.system(size: titleFontSize * 0.7))
                            .foregroundColor(Color.fromString(titleFontColor))
                    }
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .help("插入標籤：為日記添加分類標籤，如情緒、活動、思考等，幫助組織和分類日記內容")
                .frame(width: 80)  // 增加按鈕寬度以容納文字
                
                Spacer()
                
                // 添加待辦按鈕
                Button(action: addTodoItem) {
                    HStack(spacing: 4) {
                        Image(systemName: "checklist.checked")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Text("待辦")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help("添加待辦事項")
            }
            
            // 使用NSTextView代替TextEditor以實現搜尋文字高亮
            TextEditor(text: $thoughts)
                .font(.system(size: contentFontSize))
                .foregroundColor(Color.fromString(contentFontColor))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color(.textBackgroundColor).opacity(0.4))
                .cornerRadius(8)
                .onChange(of: thoughts) { oldValue, newValue in
                    diary.thoughts = newValue
                    saveContext()
                }
                // 添加接收highlightText通知的觀察者
                .background(TextHighlightObserver(textContent: thoughts))
        }
        .padding(.vertical, 5)
        .onAppear {
            if thoughts != diary.thoughts {
                thoughts = diary.thoughts
            }
        }
    }
    
    // 格式化預覽視圖
    @State private var showingFormattedPreview = false
    
    private func showFormattedPreview() {
        showingFormattedPreview = true
    }
    
    public var body: some View {
        VStack(spacing: 5) {
            // 日記頂部信息：只保留日期顯示
            HStack {
                // 日期顯示
                Text(formatDate(diary.date))
                    .font(.system(size: titleFontSize + 3))
                    .foregroundColor(Color.orange)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding(.top, 8)
            
            // 使用TabView作為主要內容區域
            TabView(selection: $selectedTab) {
                // 基本頁籤: 包含天氣和記事
                VStack(spacing: 8) {
                    // 天氣信息
                    WeatherSectionView(
                        diary: diary,
                        selectedWeather: $selectedWeather,
                        isOnline: $isOnline,
                        isLoading: $isLoading,
                        weatherService: weatherService,
                        isToday: isToday,
                        titleFontSize: titleFontSize,
                        contentFontSize: contentFontSize,
                        titleFontColor: titleFontColor,
                        switchToManual: switchToManual,
                        saveContext: saveContext
                    )
                    
                    // 文字記事區
                    thoughtsEditor
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.textBackgroundColor)).opacity(0.4))
                }
                .padding(.vertical, 8)
                .tag("basic")
                .tabItem {
                    CustomTabStyle(isSelected: selectedTab == "basic", color: .blue) {
                        Label("基本", systemImage: "note.text")
                    }
                }
                
                // 支出頁籤
                ScrollView {
                    // Add debug print on appear
                    let _ = print("Debug - Expense tab setup: type=\(DiaryEntryType.expense.rawValue), tag='expense'")
                    
                    CategoryTableView(
                        type: .expense,
                        entries: diary.expenses,
                        diary: diary,
                        onAdd: {
                            print("Debug - Expense tab onAdd callback")
                            showAddSheet(for: .expense)
                        },
                        onDelete: deleteExpenses,
                        onEdit: { entry in
                            print("Debug - Expense tab onEdit callback")
                            editEntrySheet(entry: entry, type: .expense)
                        }
                    )
                    .padding(.vertical, 8)
                }
                .tag("expense")
                .tabItem {
                    CustomTabStyle(isSelected: selectedTab == "expense", color: .green) {
                        Label(DiaryEntryType.expense.localizedName, systemImage: DiaryEntryType.expense.icon)
                    }
                }
                
                // 運動頁籤
                ScrollView {
                    CategoryTableView(
                        type: .exercise,
                        entries: diary.exercises,
                        diary: diary,
                        onAdd: { showAddSheet(for: .exercise) },
                        onDelete: deleteExercises,
                        onEdit: { editEntrySheet(entry: $0, type: .exercise) }
                    )
                    .padding(.vertical, 8)
                }
                .tag("exercise")
                .tabItem {
                    CustomTabStyle(isSelected: selectedTab == "exercise", color: .orange) {
                        Label(DiaryEntryType.exercise.localizedName, systemImage: DiaryEntryType.exercise.icon)
                    }
                }
                
                // 睡眠頁籤
                ScrollView {
                    CategoryTableView(
                        type: .sleep,
                        entries: diary.sleeps,
                        diary: diary,
                        onAdd: { showAddSheet(for: .sleep) },
                        onDelete: deleteSleeps,
                        onEdit: { editEntrySheet(entry: $0, type: .sleep) }
                    )
                    .padding(.vertical, 8)
                }
                .tag("sleep")
                .tabItem {
                    CustomTabStyle(isSelected: selectedTab == "sleep", color: .purple) {
                        Label(DiaryEntryType.sleep.localizedName, systemImage: DiaryEntryType.sleep.icon)
                    }
                }
                
                // 工作頁籤
                ScrollView {
                    // Add debug print on appear
                    let _ = print("Debug - Work tab setup: type=\(DiaryEntryType.work.rawValue), tag='work'")
                    
                    CategoryTableView(
                        type: .work,
                        entries: diary.works,
                        diary: diary,
                        onAdd: {
                            print("Debug - Work tab onAdd callback")
                            showAddSheet(for: .work)
                        },
                        onDelete: deleteWorks,
                        onEdit: { entry in
                            print("Debug - Work tab onEdit callback")
                            editEntrySheet(entry: entry, type: .work)
                        }
                    )
                    .padding(.vertical, 8)
                }
                .tag("work")
                .tabItem {
                    CustomTabStyle(isSelected: selectedTab == "work", color: .red) {
                        Label(DiaryEntryType.work.localizedName, systemImage: DiaryEntryType.work.icon)
                    }
                }
                
                // 關係頁籤
                ScrollView {
                    CategoryTableView(
                        type: .relationship,
                        entries: diary.relationships,
                        diary: diary,
                        onAdd: { showAddSheet(for: .relationship) },
                        onDelete: deleteRelationships,
                        onEdit: { editEntrySheet(entry: $0, type: .relationship) }
                    )
                    .padding(.vertical, 8)
                }
                .tag("relationship")
                .tabItem {
                    CustomTabStyle(isSelected: selectedTab == "relationship", color: .pink) {
                        Label(DiaryEntryType.relationship.localizedName, systemImage: DiaryEntryType.relationship.icon)
                    }
                }
                
                // 學習頁籤
                ScrollView {
                    CategoryTableView(
                        type: .study,
                        entries: diary.studies,
                        diary: diary,
                        onAdd: { showAddSheet(for: .study) },
                        onDelete: deleteStudies,
                        onEdit: { editEntrySheet(entry: $0, type: .study) }
                    )
                    .padding(.vertical, 8)
                }
                .tag("study")
                .tabItem {
                    CustomTabStyle(isSelected: selectedTab == "study", color: .teal) {
                        Label(DiaryEntryType.study.localizedName, systemImage: DiaryEntryType.study.icon)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.windowBackgroundColor).opacity(0.7))
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
            )
            .padding(.vertical, 5)
            .onAppear {
                // 默認選擇基本頁籤（天氣與記事）
                if selectedTab == nil {
                    selectedTab = "basic"
                }
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showingSheet) {
            if let entry = editingEntry {
                // 在編輯模式下，明確使用 entry.type 而不是 currentCategory
                CategoryEntryForm(
                    type: entry.type,
                    diary: diary,
                    editingEntry: entry
                )
                .frame(width: 450, height: 500)
                .onAppear {
                    print("Debug - Sheet presented for editing entry type: \(entry.type.rawValue)")
                }
            } else {
                // 在新增模式下使用 currentCategory
                CategoryEntryForm(
                    type: currentCategory,
                    diary: diary
                )
                .frame(width: 450, height: 500)
                .onAppear {
                    print("Debug - Sheet presented for new entry type: \(currentCategory.rawValue)")
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("關閉")))
        }
        .sheet(isPresented: $showingFormattedPreview) {
            FormattedPreviewView(diary: diary)
        }
        .onChange(of: diary.thoughts) { oldValue, newValue in
            saveContext()
        }
        .onDisappear {
            saveContext()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            print("Debug - Tab changed: \(oldValue ?? "nil") -> \(newValue ?? "nil")")
        }
    }
    
    // 格式化日期為yyyy/M/d格式
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }
    
    // 保存上下文
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // 更新天氣
    private func updateWeather() {
        // 確保有天氣服務
        guard let weatherService = weatherService else { return }
        
        isLoading = true
        
        // 使用天氣服務獲取天氣
        Task {
            do {
                // 獲取當前天氣
                let result = try await weatherService.fetchWeather()
                
                // 在主線程更新UI
                await MainActor.run {
                    // 創建新的天氣記錄
                    let newRecord = WeatherRecord(
                        time: Date(),
                        weather: result.type,
                        temperature: result.temp,
                        location: result.location
                    )
                    
                    // 添加到記錄列表
                    diary.weatherRecords.append(newRecord)
                    
                    // 更新當前狀態
                    diary.weather = result.type
                    diary.temperature = result.temp
                    selectedWeather = result.type.rawValue
                    
                    // 保存更改
                    saveContext()
                    
                    // 完成加載
                    isLoading = false
                    isOnline = true
                }
            } catch {
                // 在主線程處理錯誤
                await MainActor.run {
                    print("獲取天氣時出錯: \(error.localizedDescription)")
                    isLoading = false
                    // 如果自動獲取失敗，切換到手動模式
                    isOnline = false
                }
            }
        }
    }
    
    // 切換到手動模式
    private func switchToManual() {
        isOnline = false
        
        // 如果天氣記錄為空，設置默認天氣
        if diary.weatherRecords.isEmpty {
            // 選擇當前天氣或預設晴天
            let weatherType = WeatherType.allCases.first(where: { $0.rawValue == selectedWeather }) ?? .sunny
            
            // 設置默認天氣
            diary.weather = weatherType
            diary.temperature = diary.temperature.isEmpty ? "25°C" : diary.temperature
            
            saveContext()
        }
    }
    
    // 修改 showAddSheet 方法，以確保類型與標籤匹配
    private func showAddSheet(for type: DiaryEntryType) {
        // 確保當前有選中的標籤
        guard let currentTab = selectedTab else {
            // 如果沒有選中的標籤，使用傳入的類型
            currentCategory = type
            editingEntry = nil
            showingSheet = true
            print("Debug - No selected tab, using passed type: \(type.rawValue)")
            return
        }
        
        // 從當前選中的標籤獲取正確的類型
        let correctType = getTypeForTab(currentTab)
        print("Debug - Current tab: \(currentTab), correct type: \(correctType.rawValue)")
        
        // 如果傳入的類型與標籤不匹配，使用標籤對應的類型
        if correctType != type {
            print("Debug - WARNING: Type mismatch between passed type (\(type.rawValue)) and selected tab (\(correctType.rawValue))")
            print("Debug - Using tab type instead of passed type")
        }
        
        // 始終使用標籤對應的類型
        currentCategory = correctType
        editingEntry = nil
        
        print("Debug - Will show sheet for type: \(currentCategory.rawValue)")
        showingSheet = true
    }
    
    // Helper function to map tab names to types
    private func getTypeForTab(_ tab: String) -> DiaryEntryType {
        switch tab {
        case "work": return DiaryEntryType.work
        case "expense": return DiaryEntryType.expense
        case "exercise": return DiaryEntryType.exercise
        case "sleep": return DiaryEntryType.sleep
        case "relationship": return DiaryEntryType.relationship
        case "study": return DiaryEntryType.study
        default: return DiaryEntryType.expense // Default to expense
        }
    }
    
    // 顯示編輯表單
    private func editEntrySheet(entry: CategoryEntry, type: DiaryEntryType) {
        // Simplify debug output
        print("Debug - editEntrySheet called for entry.type=\(entry.type.rawValue), type=\(type.rawValue)")
        
        // Directly set currentCategory based on the entry's type
        currentCategory = entry.type
        
        // Only override if there's a mismatch between the passed type and the entry's type
        if entry.type != type {
            print("Debug - WARNING: Type mismatch between entry.type (\(entry.type.rawValue)) and passed type (\(type.rawValue))")
        }
        
        editingEntry = entry
        
        // Add debug message to confirm final type
        print("Debug - Will show edit sheet for type: \(currentCategory.rawValue)")
        
        showingSheet = true
    }
    
    // 刪除支出記錄
    private func deleteExpenses(_ indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(diary.expenses[index])
        }
        diary.expenses.remove(atOffsets: indexSet)
    }
    
    // 刪除運動記錄
    private func deleteExercises(_ indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(diary.exercises[index])
        }
        diary.exercises.remove(atOffsets: indexSet)
    }
    
    // 刪除睡眠記錄
    private func deleteSleeps(_ indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(diary.sleeps[index])
        }
        diary.sleeps.remove(atOffsets: indexSet)
    }
    
    // 刪除工作記錄
    private func deleteWorks(_ indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(diary.works[index])
        }
        diary.works.remove(atOffsets: indexSet)
    }
    
    // 刪除關係記錄
    private func deleteRelationships(_ indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(diary.relationships[index])
        }
        diary.relationships.remove(atOffsets: indexSet)
    }
    
    // 刪除學習記錄
    private func deleteStudies(_ indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(diary.studies[index])
        }
        diary.studies.remove(atOffsets: indexSet)
    }
    
    // 修改插入項目符號的方法
    private func insertBulletPoint() {
        // 確保插入的項目符號前沒有數字標記
        thoughts += "\n◎ "
        diary.thoughts = thoughts
        saveContext()
    }
    
    // 修改showReminderDialog方法，確保在這一處顯示對話框
    private func showReminderDialog() {
        // 重置表單數據
        reminderTitle = ""
        reminderDate = Date()
        reminderTime = Date()
        selectedRepeatType = .none
        
        // 顯示對話框
        showingReminderDialog = true
    }
    
    // 添加提醒
    private func addReminder() {
        // 組合日期和時間
        let reminderDateTime = combineDateTime(date: reminderDate, time: reminderTime)
        
        // 獲取重復類型
        let repeatType = selectedRepeatType.rawValue
        
        // 日記文本添加提醒標記
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/M/d"
        dateFormatter.locale = Locale(identifier: "zh_TW")
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.locale = Locale(identifier: "zh_TW")
        
        let repeatText = repeatType == "none" ? "" : " (重復: \(getRepeatTypeDisplayName(repeatType)))"
        let reminderText = "\n⏰ 提醒事項: \(dateFormatter.string(from: reminderDate)) \(timeFormatter.string(from: reminderTime)) \(reminderTitle)\(repeatText)"
        
        // 添加到日記內容
        if !diary.thoughts.isEmpty {
            diary.thoughts += reminderText
        } else {
            diary.thoughts = reminderText
        }
        
        // 創建新的提醒
        let reminder = Reminder(
            title: reminderTitle,
            date: reminderDateTime,
            isCompleted: false,
            repeatType: repeatType
        )
        
        // 保存提醒
        modelContext.insert(reminder)
        
        do {
            // 立即保存到持久存儲
            try modelContext.save()
            
            // 發送通知，通知ReminderListView刷新
            NotificationCenter.default.post(name: NSNotification.Name("RefreshReminders"), object: nil)
            
            // 更新界面上的文本
            thoughts = diary.thoughts
            
            // 記錄成功添加的日誌
            print("成功添加提醒: \(reminderTitle) 於 \(reminderDateTime), 重復類型: \(repeatType)")
        } catch {
            print("保存提醒時出錯: \(error.localizedDescription)")
        }
        
        // 重置提醒表單
        reminderTitle = ""
        reminderDate = Date()
        reminderTime = Date()
        showingReminderDialog = false
    }
    
    // 使用模板
    private func useTemplate() {
        // 從UserDefaults獲取模板內容
        let templateTitle = UserDefaults.standard.string(forKey: "templateTitle") ?? "我的記事模板"
        let templateContent = UserDefaults.standard.string(forKey: "templateContent") ?? ""
        
        // 如果模板內容不為空，添加到記事中
        if !templateContent.isEmpty {
            // 如果記事內容為空，直接設置為模板內容
            if thoughts.isEmpty {
                thoughts = templateContent
            } else {
                // 否則，在記事末尾添加模板內容
                thoughts += "\n\n\(templateContent)"
            }
            
            // 更新日記內容
            diary.thoughts = thoughts
            saveContext()
        }
    }
    
    // 獲取重復類型的顯示名稱
    private func getRepeatTypeDisplayName(_ repeatType: String) -> String {
        switch repeatType {
        case "daily":
            return "每日"
        case "weekly":
            return "每週"
        case "monthly":
            return "每月"
        default:
            return "一次性"
        }
    }
    
    // 添加一個輔助方法來組合日期和時間
    private func combineDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        return calendar.date(from: combinedComponents) ?? Date()
    }
    
    // 清理數字前綴函數 - 已不再需要
    private func cleanupNumberedBulletPoints(_ text: String) -> String {
        // 直接返回原文本，不做任何處理
        return text
        
        /*
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var cleanedLines: [String] = []
        
        for line in lines {
            var lineStr = String(line)
            // 檢查是否符合"數字."+"◎"的模式
            let pattern = #"^(\d+\.)(\s*)◎"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: lineStr.utf16.count)
                if let match = regex.firstMatch(in: lineStr, options: [], range: range) {
                    // 替換為只有"◎"
                    if let prefixRange = Range(match.range(at: 1), in: lineStr),
                       let spaceRange = Range(match.range(at: 2), in: lineStr) {
                        lineStr.removeSubrange(prefixRange)
                        // 保留一個空格
                        if spaceRange.isEmpty {
                            lineStr.insert(" ", at: lineStr.startIndex)
                        }
                    }
                }
            }
            cleanedLines.append(lineStr)
        }
        
        return cleanedLines.joined(separator: "\n")
        */
    }
}

// 提醒對話框視圖
struct ReminderDialog: View {
    @Binding var isPresented: Bool
    @Binding var date: Date
    @Binding var time: Date
    @Binding var title: String
    @State private var selectedRepeatType: ReminderRepeatType = .none
    var onConfirm: () -> Void
    
    // 提供一個方法獲取當前選擇的重復類型
    func getRepeatType() -> String {
        return selectedRepeatType.rawValue
    }
    
    // 使用者偏好設置
    @AppStorage("titleFontSize") private var titleFontSize: Double = 22
    @AppStorage("contentFontSize") private var contentFontSize: Double = 16
    @AppStorage("titleFontColor") private var titleFontColor: String = "Green"
    @AppStorage("contentFontColor") private var contentFontColor: String = "White"
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: titleFontSize * 1.2))
                                .foregroundColor(Color.red)
                            Text("日期")
                                .font(.system(size: titleFontSize))
                                .foregroundColor(Color.fromString(titleFontColor))
                                .fontWeight(.bold)
                                .padding(.bottom, 4)
                        }
                        
                        HStack {
//                            Spacer()
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .frame(height: 200)
                                .clipped()
                                .scaleEffect(1.4) // 放大輪式選擇器
                                .datePickerStyle(.graphical)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "zh_TW"))
                                .padding(.vertical, 18)
                            
                        }
                        
                    }
                }
                
                Section {
                    VStack() {
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: titleFontSize * 1.2))
                                .foregroundColor(Color.red)
                            Text("時間: ")
                                .font(.system(size: titleFontSize ))
                                .foregroundColor(Color.fromString(titleFontColor))
                                .fontWeight(.bold)
                                .padding(.bottom, 4)
                            Spacer()
                            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                                .font(.system(size: titleFontSize * 1.2))
                                .labelsHidden()
                                .padding()
                        }
                        
                       
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: titleFontSize * 1.2))
                                .foregroundColor(Color.red)
                            Text("提醒事項")
                                .font(.system(size: titleFontSize))
                                .foregroundColor(Color.fromString(titleFontColor))
                                .fontWeight(.bold)
                                .padding(.bottom, 4)
                        }
                        
                        TextField("請輸入提醒事項", text: $title)
                            .font(.system(size: contentFontSize * 1.2))
                            .foregroundColor(Color.fromString(contentFontColor))
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 4)
                    }
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle")
                                .font(.system(size: titleFontSize * 1.2))
                                .foregroundColor(Color.blue)
                            Text("重複")
                                .font(.system(size: titleFontSize))
                                .foregroundColor(Color.fromString(titleFontColor))
                                .fontWeight(.bold)
                                .padding(.bottom, 4)
                        }
                        
                        Picker("重複類型", selection: $selectedRepeatType) {
                            Text("不重複").tag(ReminderRepeatType.none)
                            Text("每日").tag(ReminderRepeatType.daily)
                            Text("每週").tag(ReminderRepeatType.weekly)
                            Text("每月").tag(ReminderRepeatType.monthly)
                        }
                        .pickerStyle(.segmented)
                    }
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
            .navigationTitle("新增提醒")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("確定") {
                        onConfirm()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
        .frame(width: 400, height: 550)
    }
    
    private func getRepeatDescription() -> String {
        switch selectedRepeatType {
        case .daily:
            return "此提醒將每天觸發一次"
        case .weekly:
            let weekday = Calendar.current.component(.weekday, from: date)
            let weekdaySymbol = Calendar.current.weekdaySymbols[weekday - 1]
            return "此提醒將每週\(weekdaySymbol)觸發一次"
        case .monthly:
            let day = Calendar.current.component(.day, from: date)
            return "此提醒將每月\(day)日觸發一次"
        case .none:
            return "此提醒僅在指定日期觸發一次"
        }
    }
}

// 格式化預覽視圖
struct FormattedPreviewView: View {
    let diary: DiaryEntry
    
    @Environment(\.dismiss) private var dismiss
    
    var formattedText: AttributedString {
        var result = AttributedString()
        
        // 將文本按行分割
        let lines = diary.thoughts.split(separator: "\n", omittingEmptySubsequences: false)
        
        // 處理每一行
        for (index, line) in lines.enumerated() {
            if !line.isEmpty {
                // 創建行文本，不再檢查數字前綴
                var lineString = String(line)
                
                var lineText = AttributedString(lineString)
                
                // 設置整行的基本樣式
                lineText.font = .system(size: 16) // Use default size
                lineText.foregroundColor = .primary // Use default color
                
                // 檢查是否有「◎」項目符號
                if let bulletRange = lineText.range(of: "◎") {
                    lineText[bulletRange].font = .system(size: 19) // Slightly larger
                    lineText[bulletRange].foregroundColor = .green // Use a highlight color
                }
                
                // 添加行到結果中
                result.append(lineText)
            }
            
            // 如果不是最後一行，添加換行符
            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }
        
        return result
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("美化預覽")
                    .font(.headline)
                
                Spacer()
                
                Button("關閉") {
                    dismiss()
                }
                .buttonStyle(.borderless)
            }
            .padding()
            
            ScrollView {
                Text(formattedText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.textBackgroundColor).opacity(0.4))
            .cornerRadius(8)
            .padding()
        }
        .frame(width: 500, height: 600)
    }
}

// 分類編輯視圖
struct CategoryEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var diary: DiaryEntry
    let type: DiaryEntryType
    var editingEntry: CategoryEntry?
    @Binding var isPresented: Bool
    
    // Add selectedTab parameter
    let selectedTab: String?
    
    @State private var name: String = ""
    @State private var number: Double = 0
    @State private var notes: String = ""
    @State private var category: String = ""
    
    // 新增自動完成相關狀態
    @State private var nameSuggestions: [String] = []
    @State private var showingNameSuggestions = false
    @State private var categorySuggestions: [String] = []
    @State private var showingCategorySuggestions = false
    @State private var showingCategoryOptions = false
    @FocusState private var isCategoryFocused: Bool
    @FocusState private var isNameFocused: Bool
    
    // 使用Query獲取所有日記項目用於搜尋歷史資料
    @Query private var allDiaries: [DiaryEntry]
    
    @Environment(\.colorScheme) private var colorScheme
    
    // 使用者偏好設置
    @AppStorage("titleFontSize") private var titleFontSize: Double = 22
    @AppStorage("contentFontSize") private var contentFontSize: Double = 16
    @AppStorage("titleFontColor") private var titleFontColor: String = "Green"
    @AppStorage("contentFontColor") private var contentFontColor: String = "White"
    
    // 根據條目類型獲取名稱標籤
    private var nameLabel: String {
        switch type {
        case .expense: return "名稱"
        case .exercise: return "名稱"
        case .sleep: return "品質"
        case .work: return "名稱"
        case .relationship: return "姓名"
        case .study: return "名稱"
        }
    }
    
    // 根據條目類型獲取類別標籤
    private var categoryLabel: String {
        switch type {
        case .expense: return "類別"
        case .exercise: return "運動類型"
        case .sleep: return "醒來次數"
        case .work: return "工作類型"
        case .relationship: return "關係類型"
        case .study: return "學習類型"
        }
    }
    
    // 根據條目類型獲取數值標籤
    private var numberLabel: String {
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
        VStack(spacing: 0) {
            // 標題欄
            titleBar
            
            // 內容表單
            ScrollView {
                VStack(spacing: 20) {
                    // 名稱輸入區域
                    nameInputSection
                    
                    // 類別選擇區域
                    categoryInputSection
                    
                    // 金額輸入區域
                    amountInputSection
                    
                    // 備注輸入區域
                    notesInputSection
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            
            // 底部按鈕區域
            bottomButtonBar
        }
        .frame(width: 450, height: 500)
        .background(colorScheme == .dark ? Color.black.opacity(0.8) : Color.gray.opacity(0.1))
        .onAppear {
            if let entry = editingEntry {
                name = entry.name
                number = entry.number
                notes = entry.notes
                category = entry.category
            } else if !type.categories.isEmpty {
                category = ""
            }
            
            // 如果是睡眠類型且是新增條目，初始化品質值和其他字段
            if type == .sleep && editingEntry == nil {
                name = "70%" // 預設品質值
                category = "1" // 預設醒來次數
                number = 390.0 // 預設睡眠時間，6.5小時 = 390分鐘
            }
            
            // 初始加載類別選項
            setupCategoryOptions()
        }
    }
    
    // 設置對應類型的類別選項
    private func setupCategoryOptions() {
        // 根據條目類型獲取類別選項
        showingCategoryOptions = false
        categorySuggestions = [] // 清空建議
        
        // 確保選擇正確的類型預設類別
        if !type.categories.isEmpty {
            // 如果沒有填寫類別，顯示類別選項按鈕
            if category.isEmpty {
                showingCategoryOptions = true
            }
        }
    }
    
    // MARK: - 子視圖組件
    
    private var titleBar: some View {
        HStack {
            // Get the correct title based on the tab
            let titleType = getTitleType()
            
            // Display the title
            Text(editingEntry == nil ? "新增\(titleType.rawValue)記錄" : "編輯\(titleType.rawValue)記錄")
                .font(.system(size: titleFontSize))
                .foregroundColor(Color.fromString(titleFontColor))
                .fontWeight(.bold)
                .padding()
            
            Spacer()
        }
        .background(Color.black)
        .onAppear {
            // Debug logging
            if let tab = selectedTab, getTypeForTab(tab) != type {
                print("Debug - Title mismatch: tab=\(tab), type=\(type.rawValue), corrected to \(getTypeForTab(tab).rawValue)")
            }
        }
    }
    
    // Helper function to get the correct type for the current tab
    private func getTitleType() -> DiaryEntryType {
        if let tab = selectedTab {
            return getTypeForTab(tab)
        }
        return type
    }
    
    // Helper function to map tab names to types
    private func getTypeForTab(_ tab: String) -> DiaryEntryType {
        switch tab {
        case "work": return DiaryEntryType.work
        case "expense": return DiaryEntryType.expense
        case "exercise": return DiaryEntryType.exercise
        case "sleep": return DiaryEntryType.sleep
        case "relationship": return DiaryEntryType.relationship
        case "study": return DiaryEntryType.study
        default: return DiaryEntryType.expense // Default to expense
        }
    }
    
    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題行
            HStack(spacing: 10) {
                // 根據類型使用不同的圖標
                if type == .sleep {
                    CircleIconImage(systemName: "bed.double.fill")
                } else if type == .exercise {
                    CircleIconImage(systemName: "figure.walk")
                } else if type == .work {
                    CircleIconImage(systemName: "briefcase.fill")
                } else if type == .relationship {
                    CircleIconImage(systemName: "person.2.fill")
                } else if type == .study {
                    CircleIconImage(systemName: "book.fill")
                } else {
                    CircleIcon(text: "$")
                }
                
                Text(nameLabel)
                    .foregroundColor(Color.fromString(titleFontColor))
                    .font(.system(size: titleFontSize))
            }
            
            // 輸入框
            VStack(alignment: .leading) {
                if type == .sleep {
                    // 睡眠品質使用百分比輸入
                    HStack {
                        // 提取當前百分比值（如果有）
                        let currentValue = extractPercentage(from: name)
                        
                        // 百分比滑動條
                        Slider(value: Binding(
                            get: { Double(currentValue) },
                            set: { newValue in
                                name = "\(Int(newValue))%"
                            }
                        ), in: 0...100, step: 1)
                        .padding(.horizontal, 8)
                        
                        // 顯示當前百分比
                        Text(name)
                            .font(.system(size: contentFontSize))
                            .foregroundColor(Color.fromString(contentFontColor))
                            .frame(width: 60)
                            .padding(8)
                            .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                            .cornerRadius(8)
                    }
                } else {
                    TextField("", text: $name)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(8)
                        .font(.system(size: contentFontSize))
                        .foregroundColor(Color.fromString(contentFontColor))
                        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .focused($isNameFocused)
                        .onChange(of: name) { _, newValue in
                            handleNameChange(newValue)
                        }
                }
                
                // 顯示名稱建議
                if showingNameSuggestions && !nameSuggestions.isEmpty && type != .sleep {
                    // 計算合適的高度
                    let maxHeight: CGFloat = 150
                    let itemHeight: CGFloat = 35
                    let calculatedHeight = min(CGFloat(nameSuggestions.count) * itemHeight, maxHeight)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(nameSuggestions, id: \.self) { suggestion in
                                Text(suggestion)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(5)
                                    .onTapGesture {
                                        name = suggestion
                                        showingNameSuggestions = false
                                    }
                            }
                        }
                    }
                    .frame(height: calculatedHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var categoryInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題行
            HStack(spacing: 10) {
                // 根據類型使用不同的圖標
                if type == .sleep {
                    CircleIconImage(systemName: "moon.zzz.fill")
                } else if type == .exercise {
                    CircleIconImage(systemName: "figure.strengthtraining.traditional")
                } else if type == .work {
                    CircleIconImage(systemName: "folder.fill")
                } else if type == .relationship {
                    CircleIconImage(systemName: "heart.fill")
                } else if type == .study {
                    CircleIconImage(systemName: "graduationcap.fill")
                } else {
                    CircleIconImage(systemName: "tag.fill")
                }
                
                Text(categoryLabel)
                    .foregroundColor(Color.fromString(titleFontColor))
                    .font(.system(size: titleFontSize))
            }
            
            // 輸入框與類別選項
            VStack(alignment: .leading) {
                if type == .sleep {
                    // 醒來次數使用數字選擇器
                    HStack {
                        Spacer()
                        
                        // 減少按鈕
                        Button(action: {
                            let current = Int(category) ?? 0
                            if current > 0 {
                                category = "\(current - 1)"
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 24))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        // 顯示次數
                        Text(category.isEmpty ? "0" : category)
                            .frame(width: 40)
                            .font(.system(size: contentFontSize))
                            .foregroundColor(Color.fromString(contentFontColor))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                        
                        // 增加按鈕
                        Button(action: {
                            let current = Int(category) ?? 0
                            category = "\(current + 1)"
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 24))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        Spacer()
                    }
                    .padding(8)
                    .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                } else {
                    HStack {
                        TextField("", text: $category)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(8)
                            .font(.system(size: contentFontSize))
                            .foregroundColor(Color.fromString(contentFontColor))
                            .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            )
                            .focused($isCategoryFocused)
                            .onChange(of: category) { _, newValue in
                                handleCategoryChange(newValue)
                            }
                        
                        // 下拉按鈕
                        if !type.categories.isEmpty {
                            Button(action: {
                                // 點擊時如果關閉了類別選項，則再打開時顯示當前類型的類別
                                if !showingCategoryOptions {
                                    categorySuggestions = []
                                    showingCategorySuggestions = false
                                }
                                showingCategoryOptions.toggle()
                            }) {
                                Image(systemName: showingCategoryOptions ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.gray)
                                    .padding(8)
                                    .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // 顯示類別建議或預設選項
                if showingCategorySuggestions && !categorySuggestions.isEmpty {
                    // 計算合適的高度
                    let maxHeight: CGFloat = 150
                    let itemHeight: CGFloat = 35
                    let calculatedHeight = min(CGFloat(categorySuggestions.count) * itemHeight, maxHeight)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(categorySuggestions, id: \.self) { suggestion in
                                Text(suggestion)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(category == suggestion ? Color.blue.opacity(0.1) : Color.clear)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        category = suggestion
                                        showingCategorySuggestions = false
                                    }
                                
                                if suggestion != categorySuggestions.last {
                                    Divider().padding(.horizontal, 5)
                                }
                            }
                        }
                    }
                    .padding(5)
                    .frame(height: calculatedHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .transition(.opacity)
                }
                
                if showingCategoryOptions && !type.categories.isEmpty {
                    // 計算合適的高度
                    let maxHeight: CGFloat = 200
                    let itemHeight: CGFloat = 40
                    let calculatedHeight = min(CGFloat(type.categories.count) * itemHeight, maxHeight)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(type.categories, id: \.self) { option in
                                VStack(spacing: 0) {
                                    HStack {
                                        Text(option)
                                            .font(.system(size: contentFontSize))
                                        Spacer()
                                        if category == option {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(category == option ? Color.blue.opacity(0.1) : Color.clear)
                                    .onTapGesture {
                                        category = option
                                        showingCategoryOptions = false
                                    }
                                    
                                    if option != type.categories.last {
                                        Divider().padding(.horizontal, 5)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: calculatedHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .transition(.opacity)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var amountInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題行
            HStack(spacing: 10) {
                // 根據類型使用不同的圖標
                if type == .sleep {
                    CircleIconImage(systemName: "clock.fill")
                } else if type == .exercise {
                    CircleIconImage(systemName: "timer")
                } else if type == .work {
                    CircleIconImage(systemName: "hourglass")
                } else if type == .relationship {
                    CircleIconImage(systemName: "clock.badge")
                } else if type == .study {
                    CircleIconImage(systemName: "clock.arrow.circlepath")
                } else {
                    CircleIcon(text: "#")
                }
                
                Text(numberLabel)
                    .foregroundColor(Color.fromString(titleFontColor))
                    .font(.system(size: titleFontSize))
            }
            
            // 輸入區域 - 根據類型顯示不同的輸入方式
            if type == .expense {
                // 支出金額輸入，支持四則運算
                HStack {
                    Spacer()
                    
                    // 使用State變量保存表達式字符串
                    let binding = Binding<String>(
                        get: {
                            // 如果數值是整數，不顯示小數部分
                            if number == Double(Int(number)) {
                                return String(Int(number))
                            }
                            return String(number)
                        },
                        set: { newValue in
                            // 嘗試計算四則運算表達式
                            if let result = evaluateMathExpression(newValue) {
                                number = result
                            }
                        }
                    )
                    
                    TextField("輸入金額", text: binding)
                        .textFieldStyle(PlainTextFieldStyle())
                        .multilineTextAlignment(.trailing)
                        .padding(8)
                        .font(.system(size: contentFontSize))
                        .foregroundColor(Color.fromString(contentFontColor))
                        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                        .cornerRadius(8)
                    
                    // 上下調節按鈕
                    AmountStepper(number: $number)
                }
            } else if type == .exercise || type == .sleep || type == .work || type == .relationship || type == .study {
                // 時間輸入 (h:mm格式) - 運動、睡眠、工作、關係和學習類別都使用時間輸入
                HStack {
                    Spacer()
                    
                    // 使用格式化後的時間字符串
                    let timeBinding = Binding<String>(
                        get: { formatMinutesToTimeString(Int(number)) },
                        set: { newValue in
                            // 嘗試將h:mm格式轉換為分鐘
                            let minutes = parseTimeStringToMinutes(newValue)
                            if minutes > 0 {
                                number = Double(minutes)
                            }
                        }
                    )
                    
                    TextField("輸入時間 (例如: 1:30 或直接輸入分鐘數)", text: timeBinding)
                        .textFieldStyle(PlainTextFieldStyle())
                        .multilineTextAlignment(.trailing)
                        .padding(8)
                        .font(.system(size: contentFontSize))
                        .foregroundColor(Color.fromString(contentFontColor))
                        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                        .help("請使用小時:分鐘格式，例如 1:30 表示1小時30分鐘，或直接輸入分鐘數，例如 30 表示30分鐘")
                    
                    // 上下調節按鈕 (調整分鐘)
                    VStack(spacing: 2) {
                        Button(action: {
                            number += 1
                        }) {
                            Image(systemName: "chevron.up")
                                .padding(4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Button(action: {
                            if number > 0 {
                                number -= 1
                            }
                        }) {
                            Image(systemName: "chevron.down")
                                .padding(4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.trailing, 8)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var notesInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題行
            HStack(spacing: 10) {
                CircleIconImage(systemName: "text.bubble.fill")
                Text("備註")
                    .foregroundColor(Color.fromString(titleFontColor))
                    .font(.system(size: titleFontSize))
            }
            
            // 輸入區域
            TextEditor(text: $notes)
                .font(.system(size: contentFontSize))
                .foregroundColor(Color.fromString(contentFontColor))
                .frame(minHeight: 100)
                .padding(4)
                .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                // 添加搜尋文字高亮支持
                .background(TextHighlightObserver(textContent: notes))
        }
        .padding(.horizontal)
    }
    
    private var bottomButtonBar: some View {
        HStack {
            Button("取消") {
                isPresented = false
            }
            .frame(width: 150, height: 40)
            .background(Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(20)
            
            Spacer()
            
            Button("保存") {
                saveEntry()
                isPresented = false
            }
            .frame(width: 150, height: 40)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    private func saveEntry() {
        // Debug output before saving
        print("Debug - saveEntry: type=\(type.rawValue)")
        
        // Get the correct type based on selected tab
        let correctType = getTitleType()
        
        if correctType != type {
            print("Debug - Corrected type from \(type.rawValue) to \(correctType.rawValue)")
        }
        
        if let entry = editingEntry {
            // 更新現有條目
            entry.name = name
            entry.number = number
            entry.notes = notes
            entry.category = category
            
            // Set correct type for existing entry
            if entry.type != correctType {
                print("Debug - Updated existing entry type from \(entry.type.rawValue) to \(correctType.rawValue)")
                entry.type = correctType
            }
            
            // Debug output for editing
            print("Debug - Updated existing entry: type=\(entry.type.rawValue), name=\(entry.name)")
        } else {
            // 創建新條目 - 使用正確的類型
            let newEntry = CategoryEntry(
                name: name,
                number: number,
                notes: notes,
                category: category,
                type: correctType,  // 使用正確的類型
                date: diary.date
            )
            
            // Debug output for new entry
            print("Debug - Created new entry: type=\(correctType.rawValue), name=\(name)")
            
            // 根據類型添加到對應的集合
            switch correctType {
            case .expense:
                diary.expenses.append(newEntry)
                print("Debug - Added to expenses collection")
            case .exercise:
                diary.exercises.append(newEntry)
                print("Debug - Added to exercises collection")
            case .sleep:
                diary.sleeps.append(newEntry)
                print("Debug - Added to sleeps collection")
            case .work:
                diary.works.append(newEntry)
                print("Debug - Added to works collection")
            case .relationship:
                diary.relationships.append(newEntry)
                print("Debug - Added to relationships collection")
            case .study:
                diary.studies.append(newEntry)
                print("Debug - Added to studies collection")
            }
            
            // 將新條目插入到數據上下文
            modelContext.insert(newEntry)
        }
        
        // 保存上下文
        do {
            try modelContext.save()
        } catch {
            print("保存分類條目時出錯: \(error)")
        }
    }
    
    // MARK: - 自動完成相關功能
    
    // 獲取特定類型的所有歷史條目
    private func getHistoricalEntries() -> [CategoryEntry] {
        var entries: [CategoryEntry] = []
        
        for diary in allDiaries {
            switch type {
            case .expense:
                entries.append(contentsOf: diary.expenses)
            case .exercise:
                entries.append(contentsOf: diary.exercises)
            case .sleep:
                entries.append(contentsOf: diary.sleeps)
            case .work:
                entries.append(contentsOf: diary.works)
            case .relationship:
                entries.append(contentsOf: diary.relationships)
            case .study:
                entries.append(contentsOf: diary.studies)
            }
        }
        
        return entries
    }
    
    // 處理名稱變化
    private func handleNameChange(_ newValue: String) {
        if !newValue.isEmpty {
            // 獲取歷史條目並過濾名稱
            let entries = getHistoricalEntries()
            let uniqueNames = Set(entries.map { $0.name })
            
            // 過濾並排序建議
            nameSuggestions = Array(uniqueNames)
                .filter { $0.localizedCaseInsensitiveContains(newValue) && $0 != newValue }
                .sorted()
            
            showingNameSuggestions = !nameSuggestions.isEmpty
        } else {
            showingNameSuggestions = false
        }
    }
    
    // 處理類別變化
    private func handleCategoryChange(_ newValue: String) {
        if !newValue.isEmpty {
            // 先檢查是否有預定義類別，過濾出包含輸入文字的選項
            let predefinedCategories = type.categories.filter { $0.localizedCaseInsensitiveContains(newValue) && $0 != newValue }
            
            // 從歷史條目中提取唯一類別
            let entries = getHistoricalEntries()
            let uniqueCategories = Set(entries.map { $0.category })
            
            // 過濾並排序建議，合併預定義類別和歷史類別（預定義類別優先）
            let historicalSuggestions = Array(uniqueCategories)
                .filter { $0.localizedCaseInsensitiveContains(newValue) && $0 != newValue && !predefinedCategories.contains($0) }
                .sorted()
            
            categorySuggestions = predefinedCategories + historicalSuggestions
            
            showingCategorySuggestions = !categorySuggestions.isEmpty
            showingCategoryOptions = false
        } else {
            showingCategorySuggestions = false
        }
    }
    
    // 提取百分比值
    func extractPercentage(from text: String) -> Int {
        // 嘗試從文本中提取百分比數值
        let cleanedText = text.replacingOccurrences(of: "%", with: "")
        if let value = Int(cleanedText) {
            return min(100, max(0, value)) // 確保在0-100範圍內
        }
        return 70 // 默認值
    }
}

// MARK: - 輔助組件

// 數字加減組件
struct AmountStepper: View {
    @Binding var number: Double
    
    var body: some View {
        VStack(spacing: 2) {
            Button(action: {
                number += 100 // 增加100
            }) {
                Image(systemName: "chevron.up")
                    .padding(4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Button(action: {
                if number >= 100 {
                    number -= 100 // 減少100
                }
            }) {
                Image(systemName: "chevron.down")
                    .padding(4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
        }
    }
}

// 藍色圓形圖標組件（文字版）
struct CircleIcon: View {
    let text: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// 藍色圓形圖標組件（圖片版）
struct CircleIconImage: View {
    let systemName: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 24, height: 24)
            
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }
}

// 在CategoryEditView之後添加以下工具方法

// 格式化分鐘為h:mm格式
// This function is already defined in Helpers.swift, removing the duplicate definition

// 解析h:mm格式為分鐘
func parseTimeStringToMinutes(_ timeString: String) -> Int {
    // 直接嘗試將整個字符串解析為分鐘數
    if let minutes = Int(timeString.trimmingCharacters(in: .whitespaces)) {
        return minutes
    }
    
    // 如果不是純分鐘數，則嘗試h:mm格式
    let components = timeString.split(separator: ":")
    
    // 分鐘數必須是一個合理的數字
    if components.count == 2,
       let hours = Int(components[0]),
       let minutes = Int(components[1]),
       hours >= 0, minutes >= 0, minutes < 60 {
        return hours * 60 + minutes
    } else if components.count == 1,
              let minutes = Int(components[0]),
              minutes >= 0 {
        // 處理可能的單一數字（作為小時處理）
        return minutes * 60
    }
    
    // 如果格式不正確，返回0
    return 0
}

// 計算四則運算表達式
func evaluateMathExpression(_ expression: String) -> Double? {
    // 去除所有空格
    let expr = expression.replacingOccurrences(of: " ", with: "")
    
    // 簡單的情況：直接是數字
    if let number = Double(expr) {
        return number
    }
    
    // 創建NSExpression來計算四則運算
    do {
        // 檢查表達式是否只包含有效字符
        let validChars = CharacterSet(charactersIn: "0123456789.+-*/()").union(.whitespaces)
        guard expr.rangeOfCharacter(from: validChars.inverted) == nil else {
            return nil
        }
        
        let mathExpression = NSExpression(format: expr)
        if let result = mathExpression.expressionValue(with: nil, context: nil) as? Double {
            return result
        }
        return nil
    } catch {
        // 如果計算失敗，返回nil
        return nil
    }
}

// MARK: - 自定義時間選擇元件
struct TimePickerView: View {
    @Binding var time: Date
    
    // 使用者偏好設置
    @AppStorage("titleFontSize") private var titleFontSize: Double = 22
    @AppStorage("contentFontSize") private var contentFontSize: Double = 16
    @AppStorage("titleFontColor") private var titleFontColor: String = "Green"
    @AppStorage("contentFontColor") private var contentFontColor: String = "White"
    
    // 時間格式化
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    var body: some View {
        HStack {
            Text("時間")
                .font(.system(size: titleFontSize))
                .foregroundColor(Color.fromString(titleFontColor))
                .fontWeight(.bold)
            
            Spacer()
            
            HStack(spacing: 15) {
                Text(timeFormatter.string(from: time))
                    .font(.system(size: contentFontSize * 1.2, weight: .bold))
                    .foregroundColor(Color.fromString(contentFontColor))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
                
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button(action: { adjustHour(by: 1) }) {
                            Image(systemName: "chevron.up")
                                .foregroundColor(.blue)
                                .padding(4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Button(action: { adjustMinute(by: 1) }) {
                            Image(systemName: "chevron.up")
                                .foregroundColor(.blue)
                                .padding(4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: { adjustHour(by: -1) }) {
                            Image(systemName: "chevron.down")
                                .foregroundColor(.blue)
                                .padding(4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Button(action: { adjustMinute(by: -1) }) {
                            Image(systemName: "chevron.down")
                                .foregroundColor(.blue)
                                .padding(4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }
    
    // 調整小時
    private func adjustHour(by amount: Int) {
        let calendar = Calendar.current
        time = calendar.date(byAdding: .hour, value: amount, to: time) ?? time
    }
    
    // 調整分鐘
    private func adjustMinute(by amount: Int) {
        let calendar = Calendar.current
        time = calendar.date(byAdding: .minute, value: amount, to: time) ?? time
    }
}

// 添加搜尋文本高亮功能的觀察者View
struct TextHighlightObserver: NSViewRepresentable {
    let textContent: String
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        
        // 添加通知觀察者來接收高亮文本的通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HighlightSearchText"),
            object: nil,
            queue: .main
        ) { notification in
            if let searchText = notification.object as? String,
               !searchText.isEmpty {
                self.highlightSearchText(searchText)
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // 當視圖更新時不需要做任何事情
    }
    
    // 實現搜尋文本高亮功能
    private func highlightSearchText(_ searchText: String) {
        // 嘗試獲取当前活躍的文本視圖
        DispatchQueue.main.async {
            guard let textView = findActiveTextView() else { return }
            
            // 清除現有的高亮
            let wholeRange = NSRange(location: 0, length: textView.string.count)
            textView.textStorage?.addAttribute(.backgroundColor, value: NSColor.clear, range: wholeRange)
            textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.textColor, range: wholeRange)
            
            // 尋找所有匹配的文本並高亮顯示
            do {
                let regex = try NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: searchText), options: [.caseInsensitive])
                let matches = regex.matches(in: textView.string, options: [], range: wholeRange)
                
                for match in matches {
                    // 設置背景色高亮
                    textView.textStorage?.addAttribute(.backgroundColor, value: NSColor.yellow.withAlphaComponent(0.5), range: match.range)
                    // 設置文本顏色為深色以增加對比度
                    textView.textStorage?.addAttribute(.foregroundColor, value: NSColor.black, range: match.range)
                }
                
                // 滾動到第一個匹配處（如果有）
                if let firstMatch = matches.first {
                    textView.scrollRangeToVisible(firstMatch.range)
                }
            } catch {
                print("正則表達式錯誤: \(error)")
            }
        }
    }
    
    // 嘗試找到當前活躍的TextEditor的NSTextView
    private func findActiveTextView() -> NSTextView? {
        // 獲取當前鍵盤焦點的窗口
        guard let window = NSApplication.shared.keyWindow else { return nil }
        
        // 遞歸搜索NSTextView
        return findTextView(in: window.contentView)
    }
    
    // 遞歸搜索視圖層次結構中的NSTextView
    private func findTextView(in view: NSView?) -> NSTextView? {
        guard let view = view else { return nil }
        
        // 檢查當前視圖是否為NSTextView
        if let textView = view as? NSTextView {
            return textView
        }
        
        // 遞歸搜索所有子視圖
        for subview in view.subviews {
            if let textView = findTextView(in: subview) {
                return textView
            }
        }
        
        return nil
    }
}

