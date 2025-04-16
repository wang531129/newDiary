import SwiftUI
import SwiftData
import Foundation
import UniformTypeIdentifiers
import AppKit
import WeatherKit
import Charts
import MapKit
import EventKit

// MARK: - Color 扩展
extension Color {
    // 将字符串转换为对应的颜色类型
    static func mainViewFromString(_ colorName: String) -> Color {
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

/// 应用程序的主视图，包含日记列表和详细内容
public struct MainContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @Query(sort: \DiaryEntry.date, order: .reverse) private var diaryEntries: [DiaryEntry]
    @Query(sort: \ReminderItem.date) private var reminders: [ReminderItem]
    
    @State private var selectedDate = Date()
    @State private var selectedDiary: DiaryEntry?
    @State private var isAddingDiary = false
    @State private var showingTodayReminders = false
    @State private var isUpdatingDiary = false
    @State private var isExporting = false
    
    @State private var searchText = ""
    @State private var showSearchField = false
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var activeSheet: MainContentSheetType?
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var showingPreferences = false
    @State private var showingDatePickerCalendar = false
    @State private var showingHelp = false
    @State private var showingAddReminderView = false
    @State private var todayReminders: [Reminder] = []
    @State private var selectedReminder: Reminder? = nil
    // 默认显示已完成的提醒
    @State private var showCompletedReminders = true
    
    // 调试模式
    #if DEBUG
    let isDebugMode = true
    #else
    let isDebugMode = false
    #endif
    
    // 用户偏好设置
    @AppStorage("userName") private var userName: String = "我的"
    @AppStorage("titleFontSize") private var titleFontSize: Double = 22
    @AppStorage("contentFontSize") private var contentFontSize: Double = 16
    @AppStorage("titleFontColor") private var titleFontColor: String = "Green"
    @AppStorage("contentFontColor") private var contentFontColor: String = "White"
    
    // 搜索结果结构
    struct SearchResult: Identifiable {
        let id = UUID()
        let diary: DiaryEntry           // 匹配的日记
        let fieldName: String           // 匹配的字段名
        let matchText: String           // 匹配的文本
        let matchLocation: String       // 匹配位置描述
        let tabName: String             // 匹配的頁籤名稱
    }
    
    // 搜索功能
    @State private var searchResults: [SearchResult] = []
    @State private var currentResultIndex: Int = -1
    
    // 过滤今天的日记条目
    private var todayDiaries: [DiaryEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // 确保每天只有一个日记条目，按日期排序
        let filteredEntries = diaryEntries.filter { diary in
            diary.date >= startOfDay && diary.date < endOfDay
        }
        
        // 按日期对同一天的条目进行排序（较新的在前）
        return filteredEntries.sorted { $0.date > $1.date }
    }
    
    // 显示日期选择器类型（日历或月历）
    @State private var calendarType: CalendarViewType = .month
    
    // 標籤頁選擇
    @State private var selectedTab: String? = "basic"
    
    // 导航视图设置
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    enum CalendarViewType {
        case day
        case month
    }
    
    // 备份相关状态
    @State private var showingDateRangeSheet = false
    @State private var lastExportedURL: URL? = nil
    @State private var shouldShowPathSelector = false // 是否显示路径选择器
    @State private var backupToExport: DiaryBackup? = nil // 待汇出的备份数据
    
    // 查询状态
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var searchCompleted = false
    @State private var showingBackupDialog = false
    @State private var showingDatePicker = false
    
    public init() {
        // 初始化查詢，只保留DiaryEntry查询
        let dateSortDescriptor = SortDescriptor<DiaryEntry>(\.date, order: .reverse)
        
        _diaryEntries = Query(sort: [dateSortDescriptor])
        
        // 添加調試日誌
        #if DEBUG
        print("MainContentView 初始化")
        #endif
    }
    
    // 記錄錯誤日誌
    private func logError(_ message: String) {
        #if DEBUG
        print("📕 錯誤: \(message)")
        #endif
    }
    
    // 記錄信息日誌
    private func logInfo(_ message: String) {
        #if DEBUG
        print("📘 信息: \(message)")
        #endif
    }
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ZStack {
                VStack(spacing: 0) {
                    // 日期選擇區
                    VStack {
                        // 確保有足夠的空間放置月份標題
                        Spacer().frame(height: 8)
                        
                        // 日曆視圖
                        calendarView
                            .frame(height: 320)  // 進一步增加高度
                    }
                    .padding(.top, 15)   // 增加頂部間距
                    .background(Color.black.opacity(0.05))
                    Divider()
                    // 搜尋結果區與日記列表區 - 更新為垂直佈局
                    VStack(spacing: 0) {
                        // 搜尋欄 - 直接在此顯示，而不是使用.searchable修飾符
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("搜尋日記...", text: $searchText)
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    performSearch()
                                    if !searchResults.isEmpty {
                                        currentResultIndex = 0
                                        navigateToCurrentResult()
                                    }
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    searchResults = []
                                    currentResultIndex = -1
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(8)
                        .background(Color(.textBackgroundColor).opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        
                        // 添加搜尋結果計數顯示區域，使用固定高度避免佈局變化
                        VStack {
                            if !searchResults.isEmpty {
                                HStack {
                                    Text("找到 \(searchResults.count) 個結果")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if searchResults.count > 1 {
                                        Text("當前: \(currentResultIndex+1)/\(searchResults.count)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Button(action: searchUp) {
                                            Image(systemName: "chevron.up")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.borderless)
                                        .help("上一個結果")
                                        
                                        Button(action: searchDown) {
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.borderless)
                                        .help("下一個結果")
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                                .padding([.horizontal, .top], 4)
                            }
                        }
                        .frame(height: 30)  // 給予搜尋結果區一個固定高度
                        
                        // 日記列表區
                        if !todayDiaries.isEmpty {
                            List(todayDiaries) { diary in
                                Color.clear
                                    .frame(height: 40)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedDiary = diary
                                        selectedDate = diary.date
                                    }
                            }
                            .listStyle(InsetListStyle())
                        } else {
                            // 顯示新增按鈕
                            VStack {
                                Button(action: {
                                    let newDiary = DiaryEntry(date: selectedDate)
                                    modelContext.insert(newDiary)
                                    selectedDiary = newDiary
                                    try? modelContext.save()
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                        Text("新增")
                                            .foregroundColor(.blue)
                                    }
                                    .font(.system(size: titleFontSize * 0.8))
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 20)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color(.textBackgroundColor).opacity(0.1))
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .navigationTitle("\(userName)的日記")
            // 移除searchable修飾符，因為我們已經添加了自定義搜尋欄
            // .searchable(text: $searchText, isPresented: $showSearchField, prompt: "搜尋日記...")
            // 保留鍵盤快捷鍵處理程序
            .onKeyPress(.upArrow) {
                if !searchResults.isEmpty {
                    searchUp()
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.downArrow) {
                if !searchResults.isEmpty {
                    searchDown()
                    return .handled
                }
                return .ignored
            }
            .onChange(of: searchText) { oldValue, newValue in
                if !newValue.isEmpty {
                    performSearch()
                } else {
                    searchResults = []
                    currentResultIndex = -1
                }
            }
            .keyboardShortcut("f", modifiers: [.command], localization: .withoutMirroring)
            .toolbar {
                toolbar
            }
            // 使用frame設置側邊欄的最小、理想和最大寬度
            .frame(minWidth: 250, maxWidth: 350)
        } detail: {
            ZStack {
                if let diary = selectedDiary {
                    DiaryDetailView(diary: diary, selectedTab: $selectedTab)
                        .navigationTitle("\(userName)的日記")
                } else {
                    // 當沒有選中的日記時，創建一個新的空白日記
                    DiaryDetailView(diary: DiaryEntry(date: selectedDate), selectedTab: $selectedTab)
                        .navigationTitle("\(userName)的日記")
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .navigationSplitViewColumnWidth(min: 250, ideal: 280)
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 600)
        .onAppear {
            // 首先自動創建或選擇今日日記，確保打開應用時直接顯示內容
            getOrCreateTodayDiary()
            
            // 設置環境變量以捕獲佈局問題
            setConstraintDebuggingPreferences()
            
            // 確保側邊欄可見，這裡使用更直接的方式設置寬度
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                columnVisibility = .doubleColumn
                
                #if DEBUG
                // 記錄初始化完成
                logInfo("NavigationSplitView 初始化完成，列可見性設為：\(columnVisibility)")
                #endif
            }
            
            // 在視圖出現時和活動狀態變化時更新提醒
            setupReminderUpdates()
        }
        .task {
            // 初始化应用，但不立即检查提醒
            // 延迟几秒后再检查提醒，确保数据加载完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                print("延迟执行检查提醒操作...")
                // 使用单独的方法检查提醒，确保有未完成提醒时才显示提醒对话框
                initializeAndCheckReminders()
            }
        }
        .onChange(of: selectedDate) { oldDate, newDate in
            // 當日期變更時，更新 selectedDiary
            logInfo("日期變更: \(oldDate.formatted()) -> \(newDate.formatted())")
            
            // 設置更新標誌
            isUpdatingDiary = true
            
            Task { @MainActor in
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: newDate)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                
                do {
                    // 清除當前選擇的 diary
                    selectedDiary = nil
                    
                    // 創建查詢描述符
                    var descriptor = FetchDescriptor<DiaryEntry>()
                    descriptor.predicate = #Predicate<DiaryEntry> { diary in
                        diary.date >= startOfDay && diary.date < endOfDay
                    }
                    descriptor.sortBy = [SortDescriptor(\DiaryEntry.date)]
                    
                    // 執行查詢
                    let diariesForSelectedDate = try modelContext.fetch(descriptor)
                    
                    if let newDiary = diariesForSelectedDate.first {
                        logInfo("找到日期為 \(newDate.formatted()) 的日記")
                        
                        // 等待一小段時間確保視圖已經清除
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        
                        // 更新選中的日記
                        selectedDiary = newDiary
                        
                        // 再次等待以確保更新生效
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        
                        // 強制刷新視圖
                        isUpdatingDiary.toggle()
                        
                    } else {
                        logInfo("未找到日期為 \(newDate.formatted()) 的日記")
                        selectedDiary = nil
                    }
                } catch {
                    logInfo("查詢日記失敗: \(error)")
                    selectedDiary = nil
                }
                
                // 重置更新標誌
                isUpdatingDiary = false
            }
        }
        .sheet(isPresented: $showingDateRangeSheet) {
            DateRangeView(
                startDate: $startDate,
                endDate: $endDate,
                onConfirm: exportDiaries
            )
            .frame(width: 400, height: 800)
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("確定"))
            )
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .sheet(isPresented: $showingAddReminderView) {
            AddReminderView()
                .onDisappear {
                    // 视图消失时更新提醒列表
                    updateReminderStatus()
                }
        }
    }
    
    // 添加新日記
    private func addNewDiary() {
        let newDiary = DiaryEntry(date: Date())
        modelContext.insert(newDiary)
        selectedDiary = newDiary
    }
    
    // 獲取今日提醒
    private func getTodayReminders() -> [Reminder] {
        // 使用 ReminderService 获取所有提醒，而不仅是今日提醒
        let reminderService = ReminderService(modelContext: modelContext)
        return reminderService.getAllReminders(includeCompleted: true)
    }
    
    // 更新提醒状态
    private func updateReminderStatus() {
        // 使用getAllReminders获取所有提醒
        let reminderService = ReminderService(modelContext: modelContext)
        todayReminders = reminderService.getAllReminders(includeCompleted: true)
    }
    
    // 在視圖出現時和活動狀態變化時更新提醒
    private func setupReminderUpdates() {
        // 初始加载
        updateReminderStatus()
        
        // 设置定时器，每分钟更新一次提醒状态
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            updateReminderStatus()
        }
        
        // 监听应用状态变化 - 修改为使用 NSApplication 
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            updateReminderStatus()
        }
    }
    
    // 格式化提醒日期和時間
    private func formatReminderDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
    
    // 切換提醒完成狀態
    private func toggleReminderCompletion(_ reminder: ReminderItem) {
        reminder.isCompleted.toggle()
        saveContext()
    }
    
    // MARK: - 搜尋相關方法
    
    /// 執行搜尋
    private func performSearch() {
        // 如果搜尋文本為空，清空結果
        guard !searchText.isEmpty else {
            searchResults = []
            currentResultIndex = -1
            return
        }
        
        var results: [SearchResult] = []
        
        // 遍歷所有日記進行搜尋
        for diary in diaryEntries {
            // 搜尋日期
            let dateString = diary.date.formatted(date: .abbreviated, time: .omitted)
            if dateString.localizedCaseInsensitiveContains(searchText) {
                results.append(SearchResult(diary: diary, fieldName: "日期", matchText: dateString, matchLocation: "基本信息", tabName: "basic"))
            }
            
            // 搜尋天氣
            let weatherString = diary.weather.rawValue
            if weatherString.localizedCaseInsensitiveContains(searchText) {
                results.append(SearchResult(diary: diary, fieldName: "天氣", matchText: weatherString, matchLocation: "基本信息", tabName: "basic"))
            }
            
            // 搜尋溫度信息
            if diary.temperature.localizedCaseInsensitiveContains(searchText) {
                results.append(SearchResult(diary: diary, fieldName: "溫度", matchText: diary.temperature, matchLocation: "基本信息", tabName: "basic"))
            }
            
            // 搜尋記事
            if diary.thoughts.localizedCaseInsensitiveContains(searchText) {
                results.append(SearchResult(diary: diary, fieldName: "記事", matchText: diary.thoughts, matchLocation: "基本信息", tabName: "basic"))
            }
            
            // 搜尋各類別條目
            for entry in diary.expenses {
                if searchEntryFields(entry, in: diary, categoryType: .expense, results: &results) {
                    // 匹配已添加到結果中
                }
            }
            
            // 搜尋運動記錄
            for entry in diary.exercises {
                if searchEntryFields(entry, in: diary, categoryType: .exercise, results: &results) {
                    // 匹配已添加到結果中
                }
            }
            
            // 搜尋睡眠記錄
            for entry in diary.sleeps {
                if searchEntryFields(entry, in: diary, categoryType: .sleep, results: &results) {
                    // 匹配已添加到結果中
                }
            }
            
            // 搜尋工作記錄
            for entry in diary.works {
                if searchEntryFields(entry, in: diary, categoryType: .work, results: &results) {
                    // 匹配已添加到結果中
                }
            }
            
            // 搜尋關係記錄
            for entry in diary.relationships {
                if searchEntryFields(entry, in: diary, categoryType: .relationship, results: &results) {
                    // 匹配已添加到結果中
                }
            }
            
            // 搜尋學習記錄
            for entry in diary.studies {
                if searchEntryFields(entry, in: diary, categoryType: .study, results: &results) {
                    // 匹配已添加到結果中
                }
            }
        }
        
        searchResults = results
        // 確保只有在有結果時才設置 currentResultIndex 為 0
        currentResultIndex = results.isEmpty ? -1 : 0
        
        // 如果有搜尋結果，導航到第一個結果
        if !results.isEmpty {
            navigateToCurrentResult()
        }
    }
    
    // 搜尋單個條目的各個字段
    private func searchEntryFields(_ entry: CategoryEntry, in diary: DiaryEntry, categoryType: DiaryEntryType, results: inout [SearchResult]) -> Bool {
        var foundMatch = false
        let categoryName = categoryType.rawValue
        // 根據類型決定頁籤名稱
        let tabName = getTabNameForType(categoryType)
        
        // 搜尋名稱字段
        if entry.name.localizedCaseInsensitiveContains(searchText) {
            results.append(SearchResult(
                diary: diary,
                fieldName: "名稱",
                matchText: entry.name,
                matchLocation: "\(categoryName)-\(entry.name)",
                tabName: tabName
            ))
            foundMatch = true
        }
        
        // 搜尋類別字段
        if entry.category.localizedCaseInsensitiveContains(searchText) {
            results.append(SearchResult(
                diary: diary,
                fieldName: "類別",
                matchText: entry.category,
                matchLocation: "\(categoryName)-\(entry.name)",
                tabName: tabName
            ))
            foundMatch = true
        }
        
        // 搜尋備注字段
        if entry.notes.localizedCaseInsensitiveContains(searchText) {
            results.append(SearchResult(
                diary: diary,
                fieldName: "備注",
                matchText: entry.notes,
                matchLocation: "\(categoryName)-\(entry.name)",
                tabName: tabName
            ))
            foundMatch = true
        }
        
        // 搜尋數字（轉為字符串後搜尋）
        let numberString = String(format: "%.0f", entry.number)
        if numberString.localizedCaseInsensitiveContains(searchText) {
            results.append(SearchResult(
                diary: diary,
                fieldName: "數量",
                matchText: numberString,
                matchLocation: "\(categoryName)-\(entry.name)",
                tabName: tabName
            ))
            foundMatch = true
        }
        
        return foundMatch
    }
    
    // 添加輔助方法，根據條目類型獲取對應的頁籤名稱
    private func getTabNameForType(_ type: DiaryEntryType) -> String {
        switch type {
        case .expense: return "expense"
        case .exercise: return "exercise"
        case .sleep: return "sleep"
        case .work: return "work"
        case .relationship: return "relationship"
        case .study: return "study"
        }
    }
    
    // 向上搜尋
    private func searchUp() {
        guard !searchResults.isEmpty else { return }
        
        if currentResultIndex > 0 {
            currentResultIndex -= 1
        } else {
            // 循環回到最後一個結果
            currentResultIndex = searchResults.count - 1
        }
        
        navigateToCurrentResult()
    }
    
    // 向下搜尋
    private func searchDown() {
        guard !searchResults.isEmpty else { return }
        
        if currentResultIndex < searchResults.count - 1 {
            currentResultIndex += 1
        } else {
            // 循環回到第一個結果
            currentResultIndex = 0
        }
        
        navigateToCurrentResult()
    }
    
    // 導航到當前搜尋結果
    private func navigateToCurrentResult() {
        guard !searchResults.isEmpty && currentResultIndex >= 0 && currentResultIndex < searchResults.count else { return }
        
        let result = searchResults[currentResultIndex]
        selectedDiary = result.diary
        selectedDate = result.diary.date
        
        // 設置 selectedTab 以切換到正確的頁籤
        selectedTab = result.tabName
        
        // 發送通知以高亮顯示搜尋文字
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 給足夠時間讓視圖加載完成
            NotificationCenter.default.post(
                name: NSNotification.Name("HighlightSearchText"),
                object: searchText
            )
        }
        
        // 打印日誌幫助調試
        print("導航到結果：日期=\(result.diary.date.formatted()), 頁籤=\(result.tabName), 匹配=\(result.fieldName)")
    }
    
    // MARK: - 工具列操作
    
    // 切換搜尋欄位
    private func toggleSearchField() {
        withAnimation {
            showSearchField.toggle()
            if !showSearchField {
                searchText = ""
                searchResults = []
                currentResultIndex = -1
            }
        }
    }
    
    // 切換到今天的日記
    private func switchToToday() {
        selectedDate = Date()
    }
    
    // MARK: - 日記操作
    
    // 刪除日記
    private func deleteEntry(_ entry: DiaryEntry) {
        modelContext.delete(entry)
        
        // 如果刪除的是當前顯示的日記，清除選擇
        if selectedDiary?.id == entry.id {
            selectedDiary = nil
        }
        
        // 顯示操作成功提示
        alertTitle = "刪除成功"
        alertMessage = "日記已成功刪除"
        showingAlert = true
    }
    
    // 為當前選擇的日期創建新日記
    private func createDiaryForSelectedDate() {
        // 檢查是否已經存在該日期的日記
        if todayDiaries.isEmpty {
            // 不存在，創建新的
            let newDiary = DiaryEntry(date: selectedDate, thoughts: "")
            modelContext.insert(newDiary)
            try? modelContext.save()
            selectedDiary = newDiary
        } else if let firstDiary = todayDiaries.first {
            // 已存在，選中第一個
            selectedDiary = firstDiary
        }
    }
    
    // MARK: - 備份相關方法
    
    // 顯示日期範圍選擇（用於匯出）
    private func showDateRangeExport() {
        startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        endDate = Date()
        showingDateRangeSheet = true
    }
    
    // 顯示備份選擇
    private func showBackupSelection() {
        importBackup()
    }
    
    // 匯出日記數據
    private func exportDiaries() {
        // 篩選日記條目
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfNextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))!
        
        // 僅選擇日期範圍內的日記
        let filteredEntries = diaryEntries.filter { diary in
            diary.date >= startOfDay && diary.date < endOfNextDay
        }
        
        // 檢查是否有日記條目
        if filteredEntries.isEmpty {
            alertTitle = "匯出失敗"
            alertMessage = "選定的日期範圍內沒有日記條目。"
            showingAlert = true
            return
        }
        
        // 建立備份數據結構
        let backup = DiaryBackup(
            entries: filteredEntries.map { diary in
                return DiaryBackup.DiaryBackupEntry(
                    id: UUID(),
                    date: diary.date,
                    weatherRaw: diary.weather.rawValue,
                    thoughts: diary.thoughts,
                    temperature: diary.temperature,
                    weatherRecords: diary.weatherRecords.map { record in
                        DiaryBackup.WeatherRecordBackupEntry(
                            time: record.time,
                            weatherRaw: record.weather.rawValue,
                            temperature: record.temperature,
                            location: record.location
                        )
                    },
                    expenses: diary.expenses.map { convertToBackupEntry($0) },
                    exercises: diary.exercises.map { convertToBackupEntry($0) },
                    sleeps: diary.sleeps.map { convertToBackupEntry($0) },
                    works: diary.works.map { convertToBackupEntry($0) },
                    relationships: diary.relationships.map { convertToBackupEntry($0) },
                    studies: diary.studies.map { convertToBackupEntry($0) }
                )
            }
        )
        
        // 選擇匯出方式
        let alert = NSAlert()
        alert.messageText = "匯出備份"
        alert.informativeText = "確定要匯出所選範圍的日記數據嗎？"
        alert.addButton(withTitle: "確定")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // 用戶確認後進行匯出
            let defaultURL = getDefaultBackupURL()
            exportBackup(backup, to: defaultURL)
        } else {
            logInfo("用戶取消了恢復操作")
        }
    }
    
    // 從備份恢復
    private func restoreBackup(from url: URL) {
        let result = BackupManager.shared.loadBackup(from: url)
        
        switch result {
        case .success(let backup):
            do {
                logInfo("開始執行智能恢復備份操作...")
                
                // 確定備份中的日期範圍
                guard !backup.entries.isEmpty else {
                    alertTitle = "恢復失敗"
                    alertMessage = "備份文件沒有任何日記條目"
                    showingAlert = true
                    return
                }
                
                // 獲取備份中的日期範圍
                let backupDates = backup.entries.map { $0.date }
                let startDate = backupDates.min() ?? Date()
                let endDate = backupDates.max() ?? Date()
                logInfo("備份數據日期範圍：\(startDate) 到 \(endDate)")
                
                // 創建一個字典來儲存現有條目，以日期為鍵
                let calendar = Calendar.current
                var existingEntriesByDay = [String: DiaryEntry]()
                
                // 用於確定日期的函數
                func dateKey(from date: Date) -> String {
                    let components = calendar.dateComponents([.year, .month, .day], from: date)
                    return "\(components.year!)-\(components.month!)-\(components.day!)"
                }
                
                // 收集所有現有條目，按日期分類
                for entry in diaryEntries {
                    let key = dateKey(from: entry.date)
                    existingEntriesByDay[key] = entry
                }
                
                // 收集備份條目，按日期分類
                var backupEntriesByDay = [String: DiaryBackup.DiaryBackupEntry]()
                for entry in backup.entries {
                    let key = dateKey(from: entry.date)
                    backupEntriesByDay[key] = entry
                }
                
                // 確定需要刪除的條目（在備份日期範圍內的現有條目）
                var entriesToDelete = [DiaryEntry]()
                var daysToProcess = Set<String>()
                
                for (key, entry) in existingEntriesByDay {
                    if entry.date >= startDate && entry.date <= endDate {
                        // 只有當備份中也包含該日期時才刪除
                        if backupEntriesByDay[key] != nil {
                            entriesToDelete.append(entry)
                            daysToProcess.insert(key)
                        }
                    }
                }
                
                // 添加備份中有但現有數據沒有的日期
                for (key, _) in backupEntriesByDay {
                    if existingEntriesByDay[key] == nil {
                        daysToProcess.insert(key)
                    }
                }
                
                logInfo("需要刪除的現有條目數：\(entriesToDelete.count)")
                logInfo("需要處理的日期數：\(daysToProcess.count)")
                
                // 刪除在備份範圍內的現有條目
                for entry in entriesToDelete {
                    modelContext.delete(entry)
                }
                
                logInfo("已刪除選定的現有條目")
                
                // 恢復備份數據
                var successCount = 0
                var failureCount = 0
                let preservedCount = diaryEntries.count - entriesToDelete.count
                
                // 批量處理備份條目
                let batchSize = 5 // 每批處理的條目數量
                let daysArray = Array(daysToProcess)
                let totalDays = daysArray.count
                
                for batchIndex in stride(from: 0, to: totalDays, by: batchSize) {
                    // 確定當前批次的結束索引
                    let endIndex = min(batchIndex + batchSize, totalDays)
                    let batchDays = daysArray[batchIndex..<endIndex]
                    
                    logInfo("處理批次 \(batchIndex/batchSize + 1)，日期 \(batchIndex+1) 到 \(endIndex)")
                    
                    for day in batchDays {
                        // 只處理備份中存在的日期
                        guard let backupEntry = backupEntriesByDay[day] else {
                            continue
                        }
                        
                        do {
                            // 將天氣記錄轉換為 WeatherRecord 對象
                            let weatherRecords = backupEntry.weatherRecords.map { weatherBackup -> WeatherRecord in
                                return WeatherRecord(
                                    time: weatherBackup.time,
                                    weather: WeatherType(rawValue: weatherBackup.weatherRaw) ?? .sunny,
                                    temperature: weatherBackup.temperature,
                                    location: weatherBackup.location
                                )
                            }
                            
                            // 創建新的DiaryEntry
                            let diary = DiaryEntry.createFromBackup(
                                id: UUID(),
                                date: backupEntry.date,
                                thoughts: backupEntry.thoughts,
                                weather: WeatherType(rawValue: backupEntry.weatherRaw) ?? .sunny,
                                temperature: backupEntry.temperature,
                                weatherRecords: weatherRecords,
                                expenses: [],
                                exercises: [],
                                sleeps: [],
                                works: [],
                                relationships: [],
                                studies: []
                            )
                            
                            // 插入日記條目
                            modelContext.insert(diary)
                            
                            // 單獨處理各類別條目
                            // 支出
                            for expense in backupEntry.expenses {
                                let categoryEntry = createCategoryEntry(expense, type: .expense)
                                diary.expenses.append(categoryEntry)
                            }
                            
                            // 運動
                            for exercise in backupEntry.exercises {
                                let categoryEntry = createCategoryEntry(exercise, type: .exercise)
                                diary.exercises.append(categoryEntry)
                            }
                            
                            // 睡眠
                            for sleep in backupEntry.sleeps {
                                let categoryEntry = createCategoryEntry(sleep, type: .sleep)
                                diary.sleeps.append(categoryEntry)
                            }
                            
                            // 工作
                            for work in backupEntry.works {
                                let categoryEntry = createCategoryEntry(work, type: .work)
                                diary.works.append(categoryEntry)
                            }
                            
                            // 人際關係
                            for relationship in backupEntry.relationships {
                                let categoryEntry = createCategoryEntry(relationship, type: .relationship)
                                diary.relationships.append(categoryEntry)
                            }
                            
                            // 學習
                            for study in backupEntry.studies {
                                let categoryEntry = createCategoryEntry(study, type: .study)
                                diary.studies.append(categoryEntry)
                            }
                            
                            successCount += 1
                        } catch {
                            logError("恢復單個日記條目時出錯: \(error)")
                            failureCount += 1
                        }
                    }
                    
                    // 每批次處理完保存一次上下文
                    try modelContext.save()
                }
                
                logInfo("嘗試保存恢復的數據...")
                try modelContext.save()
                logInfo("成功保存恢復的數據")
                
                // 更新UI
                if let firstDiary = diaryEntries.first {
                    selectedDate = firstDiary.date
                    logInfo("已選中第一篇恢復的日記")
                }
                
                // 格式化日期範圍
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy/MM/dd"
                let formattedStartDate = dateFormatter.string(from: startDate)
                let formattedEndDate = dateFormatter.string(from: endDate)
                
                // 顯示成功訊息
                alertTitle = "恢復成功"
                alertMessage = "已成功恢復 \(successCount) 篇日記" +
                    (failureCount > 0 ? "，\(failureCount) 篇恢復失敗" : "") +
                    "，\(preservedCount) 篇現有日記被保留" +
                    "\n\n備份日期範圍：\(formattedStartDate) 至 \(formattedEndDate)" +
                    "\n備份來源：\n\(url.path)"
                lastExportedURL = url
                
                // 使用標準警告而非自定義對話框
                showingAlert = true
            } catch {
                logError("保存恢復的數據時出錯: \(error)")
                alertTitle = "恢復失敗"
                alertMessage = "保存恢復的數據時出錯：\(error.localizedDescription)"
                showingAlert = true
            }
            
        case .failure(let error):
            logError("讀取備份文件時出錯: \(error)")
            alertTitle = "恢復失敗"
            alertMessage = "讀取備份文件時出錯：\(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    // 將各種條目轉換為備份條目格式
    private func convertToBackupEntry(_ entry: CategoryEntry) -> DiaryBackup.CategoryBackupEntry {
        return DiaryBackup.CategoryBackupEntry(
            id: UUID(),
            typeRaw: entry.type.rawValue,
            name: entry.name,
            category: entry.category,
            number: entry.number,
            notes: entry.notes
        )
    }
    
    // 從備份數據創建分類條目
    private func createCategoryEntry(_ backup: DiaryBackup.CategoryBackupEntry, type: DiaryEntryType) -> CategoryEntry {
        // 使用靜態工廠方法創建
        return CategoryEntry.createFromBackup(
            name: backup.name,
            number: backup.number,
            notes: backup.notes,
            category: backup.category,
            type: type,
            date: Date() // 添加當前日期
        )
    }
    
    // 初始化並检查提醒
    private func initializeAndCheckReminders() {
        // 使用ReminderService获取所有提醒
        let reminderService = ReminderService(modelContext: modelContext)
        
        // 首先修复所有提醒的重复类型
        reminderService.fixAllReminderTypes()
        
        // 测试现有提醒的重复类型
        testExistingReminders()
        
        // 获取所有提醒（包括已完成和未完成）
        todayReminders = reminderService.getAllReminders(includeCompleted: true)
        
        // 調試輸出
        print("獲取到 \(todayReminders.count) 個提醒，其中 \(todayReminders.filter { !$0.isCompleted }.count) 個未完成")
        for (index, reminder) in todayReminders.enumerated() {
            print("提醒[\(index)]: 標題=\(reminder.title), 日期=\(formatDateTime(reminder.date)), 重複類型=\(reminder.repeatType), 完成狀態=\(reminder.isCompleted)")
        }
        
        // 檢查是否有未完成的提醒，如果有則自動顯示提醒對話框
        let uncompletedReminders = todayReminders.filter { !$0.isCompleted }
        if !uncompletedReminders.isEmpty {
            print("發現 \(uncompletedReminders.count) 個未完成提醒，自動顯示提醒對話框")
            showingTodayReminders = true
        } else {
            print("沒有未完成的提醒")
        }
    }
    
    // 测试所有现有提醒的重复类型（调试用）
    private func testExistingReminders() {
        do {
            var descriptor = FetchDescriptor<Reminder>()
            let allReminders = try modelContext.fetch(descriptor)
            
            print("===== 开始测试所有提醒的重复类型 =====")
            print("总共有 \(allReminders.count) 个提醒")
            
            for reminder in allReminders {
                // 打印提醒信息
                print("提醒: \(reminder.title)")
                print("  日期: \(reminder.date)")
                print("  重复类型: \(reminder.repeatType)")
                print("  是否完成: \(reminder.isCompleted)")
                
                // 测试重复类型检测
                reminder.checkAndPrintRepeatType()
                print("-----")
            }
            
            print("===== 测试完成 =====")
        } catch {
            print("获取提醒失败: \(error)")
        }
    }
    
    private func markReminderAsCompleted(_ reminder: Reminder) {
        let reminderService = ReminderService(modelContext: modelContext)
        reminderService.completeReminder(reminder)
        
        // 从列表中移除
        if let index = todayReminders.firstIndex(where: { $0.id == reminder.id }) {
            todayReminders.remove(at: index)
        }
        
        // 如果没有更多未完成提醒，关闭对话框
        if todayReminders.isEmpty {
            showingTodayReminders = false
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // 顯示日期選擇器
    private var calendarView: some View {
        VStack(spacing: 8) {
            // 日历视图 - 固定在底部
            CustomDatePickerView(
                selectedDate: $selectedDate,
                titleFontColor: titleFontColor,
                contentFontColor: contentFontColor,
                selectedDiary: Binding<Any?>(
                    get: { selectedDiary },
                    set: { _ in }
                ),
                diaryDates: diaryEntries.map { $0.date },
                isPopover: false
            )
            .frame(minHeight: 280)
            .clipped()
            .id(selectedDate) // 添加id确保视图在日期变化时刷新
        }
        .padding(.horizontal)
        .background(Color.black.opacity(0.05))
    }
    
    // 打開日期選擇器
    private func openDatePicker() {
        // 這裡可以實現彈出日期選擇器的邏輯
    }
    
    // 獲取日記內容的第一行
    private func getFirstLine(from text: String) -> String {
        let lines = text.split(separator: "\n", maxSplits: 1)
        if lines.isEmpty {
            return "無紀錄"
        }
        return " \(lines[0])"
    }
    
    // 標準格式化日期 yyyy/m/d
    private var standardFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: selectedDate)
    }
    
    // 當前日期顯示 - 確保在同一行內顯示
    private var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: selectedDate)
    }
    
    // 格式化日期-月/日/年格式
    private var formattedMonthDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: selectedDate)
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }
    
    // 調整日期
    private func moveDate(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    // 顯示日記列表
    private var diaryListView: some View {
        VStack(spacing: 0) {
            // 添加搜尋結果計數顯示，只在有搜尋結果時顯示
            if !searchResults.isEmpty {
                HStack {
                    Text("找到 \(searchResults.count) 個結果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if searchResults.count > 1 {
                        Text("當前: \(currentResultIndex+1)/\(searchResults.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: searchUp) {
                            Image(systemName: "chevron.up")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("上一個結果")
                        
                        Button(action: searchDown) {
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("下一個結果")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)  // 增加垂直間距使其更明顯
                .background(Color.blue.opacity(0.1))  // 使用更明顯的背景色
                .cornerRadius(4)  // 圓角邊框
                .padding([.horizontal, .top], 4)  // 外部邊距
            }
            
            // 原有的日記列表
            if !todayDiaries.isEmpty {
                List(todayDiaries) { diary in
                    Color.clear
                        .frame(height: 40)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDiary = diary
                            selectedDate = diary.date
                        }
                }
                .listStyle(InsetListStyle())
            } else {
                // 顯示新增按鈕
                VStack {
                    Button(action: {
                        let newDiary = DiaryEntry(date: selectedDate)
                        modelContext.insert(newDiary)
                        selectedDiary = newDiary
                        try? modelContext.save()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("新增")
                                .foregroundColor(.blue)
                        }
                        .font(.system(size: titleFontSize * 0.8))
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color(.textBackgroundColor).opacity(0.1))
            }
        }
        // 右鍵選單
        .contextMenu {
            Button(action: {
                let newDiary = DiaryEntry(date: selectedDate)
                modelContext.insert(newDiary)
                selectedDiary = newDiary
                try? modelContext.save()
            }) {
                Label("新增日誌", systemImage: "plus")
            }
            
            if !todayDiaries.isEmpty {
                Button(role: .destructive, action: {
                    if let diary = todayDiaries.first {
                        deleteEntry(diary)
                    }
                }) {
                    Label("刪除日記", systemImage: "trash")
                }
            }
        }
    }
    
    // 顯示日期選擇器類型選擇
    private var calendarTypeToggle: some View {
        // 實現日期選擇器類型選擇的邏輯
        Text("日期選擇器類型")
    }
    
    // 顯示設置選項
    private var settingsButton: some View {
        // 實現設置選項的邏輯
        Text("設置")
    }
    
    // 檢查今日日記
    private func checkForTodayDiary() {
        do {
            if todayDiary == nil {
                // 沒有今日的日記，自動創建一個
                let newDiary = DiaryEntry(date: Date(), thoughts: "")
                modelContext.insert(newDiary)
                
                do {
                    try modelContext.save()
                    logInfo("創建今日日記並保存成功")
                } catch {
                    logError("創建今日日記保存失敗: \(error)")
                }
                
                // 自動選中今日日記
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.selectedDate = newDiary.date
                    logInfo("已選中新創建的今日日記")
                }
            } else {
                // 有今日日記，直接選中
                logInfo("找到今日日記")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.selectedDate = self.todayDiary!.date
                    logInfo("已選中今日日記")
                }
            }
        } catch {
            logError("檢查今日日記時出錯: \(error)")
            
            // 嘗試處理"無法解碼原因"錯誤
            if error.localizedDescription.contains("decode") {
                logError("遇到解碼錯誤，可能是數據模型變更或損壞。嘗試強制創建新日記...")
                
                // 強制創建新日記
                let forcedNewDiary = DiaryEntry(date: Date(), thoughts: "")
                modelContext.insert(forcedNewDiary)
                
                do {
                    try modelContext.save()
                    logInfo("強制創建新日記成功")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.selectedDate = forcedNewDiary.date
                        logInfo("已選中強制創建的新日記")
                    }
                } catch {
                    logError("強制創建新日記失敗: \(error)")
                }
            }
        }
    }
    
    // 過濾日記
    private var filteredDiaries: [DiaryEntry] {
        var diaries = diaryEntries
        
        // 應用日期範圍過濾
        diaries = diaries.filter { diary in
            let startOfDay = Calendar.current.startOfDay(for: startDate)
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate)!
            return diary.date >= startOfDay && diary.date <= endOfDay
        }
        
        // 應用搜索文本過濾
        if !searchText.isEmpty {
            diaries = diaries.filter { diary in
                diary.thoughts.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return diaries
    }
    
    // 顯示偏好設置
    private func showPreferences() {
        showingPreferences = true
    }
    
    // 顯示幫助頁面
    private func showHelp() {
        showingHelp = true
    }
    
    // 年份部分
    private var yearPart: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: selectedDate)
    }
    
    // 月份部分
    private var monthPart: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M"
        return formatter.string(from: selectedDate)
    }
    
    // 日部分
    private var dayPart: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: selectedDate)
    }
    
    // 查找本地備份（靜態方法，供BackupSelectionView使用）
    static func findLocalBackupsStatic() -> [URL] {
        // 使用BackupManager提供的方法來獲取備份文件
        return BackupManager.shared.getBackupFiles()
    }
    
    // 設置約束調試選項
    private func setConstraintDebuggingPreferences() {
        #if DEBUG
        // 在UserDefaults中啟用約束可視化
        UserDefaults.standard.set(true, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")
        
        // 設置環境變量以獲取更詳細的CoreSVG日誌
        setenv("CORESVG_VERBOSE", "1", 1)
        
        // 使用Swizzling技術修復NavigationSplitView約束衝突問題
        fixNavigationSplitViewConstraints()
        
        logInfo("已啟用佈局約束調試")
        #endif
    }
    
    // 使用Runtime方法解決NavigationSplitView的系統約束衝突問題
    private func fixNavigationSplitViewConstraints() {
        #if DEBUG
        // 使用UserDefaults覆蓋系統默認值
        UserDefaults.standard.set(250, forKey: "NSSplitView_SidebarMinWidth")
        UserDefaults.standard.set(350, forKey: "NSSplitView_SidebarMaxWidth")
        
        // 記錄修復嘗試
        logInfo("已嘗試修復NavigationSplitView約束衝突")
        #endif
    }
    
    // 匯入備份
    private func importBackup() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = "選擇日記備份檔案"
        openPanel.allowedFileTypes = ["json"]
        openPanel.prompt = "選擇"
        
        let response = openPanel.runModal()
        
        if response == NSApplication.ModalResponse.OK, let url = openPanel.url {
            // 確認恢復對話框
            let alert = NSAlert()
            alert.messageText = "確認恢復備份"
            alert.informativeText = "智能恢復模式：\n\n· 僅替換備份中包含的日期資料\n· 不在備份日期範圍內的資料將被保留\n· 重複日期的資料將被覆蓋\n· 缺少的日期會被新增\n\n確定要繼續嗎？"
            alert.addButton(withTitle: "繼續")
            alert.addButton(withTitle: "取消")
            alert.alertStyle = .warning
            
            let alertResponse = alert.runModal()
            
            if alertResponse == NSApplication.ModalResponse.alertFirstButtonReturn {
                // 用戶確認後進行恢復
                restoreBackup(from: url)
            } else {
                logInfo("用戶取消了恢復操作")
            }
        }
    }
    
    // 獲取默認的備份URL
    private func getDefaultBackupURL() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        // 使用文檔目錄而非下載目錄，避免權限問題
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // 確保備份目錄存在
        let backupsDir = documentsURL.appendingPathComponent("DiaryBackups", isDirectory: true)
        
        // 嘗試創建目錄（如果不存在）
        try? FileManager.default.createDirectory(at: backupsDir, withIntermediateDirectories: true)
        
        return backupsDir.appendingPathComponent("DiaryBackup_\(timestamp).json")
    }
    
    // 選擇匯出路徑
    private func selectExportPath(for backup: DiaryBackup) {
        // 由於 NSSavePanel 可能導致應用程序崩潰，改為使用固定路徑並提供查看選項
        let defaultURL = getDefaultBackupURL()
        exportBackup(backup, to: defaultURL)
        
        // 顯示詢問是否打開檔案的提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let alert = NSAlert()
            alert.messageText = "備份已保存"
            alert.informativeText = "檔案已保存到：\n\(defaultURL.path)\n\n是否要在訪達中查看該檔案？"
            alert.addButton(withTitle: "查看檔案")
            alert.addButton(withTitle: "關閉")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // 在訪達中顯示檔案
                NSWorkspace.shared.selectFile(defaultURL.path, inFileViewerRootedAtPath: "")
            }
        }
    }
    
    // 匯出備份到指定URL
    private func exportBackup(_ backup: DiaryBackup, to url: URL) {
        do {
            // 編碼備份數據
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601  // 添加日期編碼策略
            let data = try encoder.encode(backup)
            
            
            // 寫入檔案
            try data.write(to: url, options: .atomic)  // 使用原子寫入確保文件完整性
            
            // 顯示成功訊息
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd"
            let formattedStartDate = dateFormatter.string(from: startDate)
            let formattedEndDate = dateFormatter.string(from: endDate)
            
            alertTitle = "匯出成功"
            alertMessage = "備份已成功保存\n\n日期範圍：\(formattedStartDate) 至 \(formattedEndDate)\n共匯出 \(backup.entries.count) 篇日記\n\n保存位置：\n\(url.path)"
            lastExportedURL = url
            showingAlert = true
            
            logInfo("成功匯出備份到: \(url.path)")
        } catch {
            // 顯示錯誤訊息
            alertTitle = "匯出失敗"
            alertMessage = "保存備份時發生錯誤：\(error.localizedDescription)"
            showingAlert = true
            
            logError("匯出備份失敗: \(error)")
        }
    }
    
    // 輔助方法來獲取顏色
    private func getColorFromString(_ colorName: String) -> Color {
        return Color.mainViewFromString(colorName)
    }
    
    // 當前選擇的日記
    private var todayDiary: DiaryEntry? {
        let calendar = Calendar.current
        return diaryEntries.first { calendar.isDateInToday($0.date) }
    }
    
    // 載入選定日期的日記
    private func loadDiaryForSelectedDate() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // 嘗試查找選定日期的日記
        let matchedDiary = diaryEntries.first { diary in
            diary.date >= startOfDay && diary.date < endOfDay
        }
        
        selectedDiary = matchedDiary
    }
    
    // 刪除選定日期日記前的確認動作
    private func confirmDeleteSelectedDateDiary() {
        // 檢查是否有選定日期的日記
        if let diary = todayDiaries.first {
            // 使用系統警告框確認刪除
            let alert = NSAlert()
            alert.messageText = "確認刪除"
            alert.informativeText = "您確定要刪除 \(formatDate(diary.date)) 的日記嗎？此操作無法撤銷。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "刪除")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                // 用戶確認刪除
                deleteEntry(diary)
            }
        } else {
            // 如果沒有選中日記，顯示錯誤訊息
            alertTitle = "無法刪除"
            alertMessage = "當前日期沒有日記可以刪除"
            showingAlert = true
        }
    }
    
    // 刪除當前日記前的確認動作
    private func confirmDeleteCurrentDiary() {
        guard let diary = selectedDiary else {
            // 如果沒有選中日記，顯示錯誤訊息
            alertTitle = "無法刪除"
            alertMessage = "請先選擇一篇日記"
            showingAlert = true
            return
        }
        
        // 使用系統警告框確認刪除
        let alert = NSAlert()
        alert.messageText = "確認刪除"
        alert.informativeText = "您確定要刪除 \(formatDate(diary.date)) 的日記嗎？此操作無法撤銷。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "刪除")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // 用戶確認刪除
            deleteEntry(diary)
        }
    }
    
    // 新增：創建或選擇今日日記
    @discardableResult
    private func getOrCreateTodayDiary() -> DiaryEntry {
        if let existingDiary = todayDiary {
            // 如果今天已有日記，則選擇它
            selectedDiary = existingDiary
            return existingDiary
        } else {
            // 如果今天沒有日記，則創建一個新的
            let newDiary = DiaryEntry(date: Date(), thoughts: "")
            modelContext.insert(newDiary)
            
            do {
                try modelContext.save()
                logInfo("自動創建今日日記成功")
            } catch {
                logError("自動創建今日日記失敗: \(error)")
            }
            
            selectedDiary = newDiary
            return newDiary
        }
    }
    
    // 刪除提醒事項
    private func deleteReminder(_ reminder: ReminderItem) {
        modelContext.delete(reminder)
        saveContext()
    }
    
    // 工具列
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // 提醒按鈕
            Button(action: { 
                // 获取最新提醒数据并显示弹窗
                checkTodayReminders() 
            }) {
                Image(systemName: "bell.badge")
                    .overlay(
                        // 显示总提醒数
                        Text("\(todayReminders.count)")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(2)
                            .background(Color.red)
                            .clipShape(Circle())
                            .opacity(todayReminders.isEmpty ? 0 : 1)
                            .offset(x: 8, y: -8)
                    )
            }
            .help("顯示提醒事項")
            .customCursor(.pointingHand)
            .popover(isPresented: $showingTodayReminders) {
                VStack {
                    // 标题栏
                    HStack {
                        Text("提醒事項")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            showingTodayReminders = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 5)
                    
                    // 切换显示已完成提醒的选项
                    Toggle("顯示已完成提醒", isOn: $showCompletedReminders)
                        .padding(.horizontal)
                        .padding(.bottom, 5)
                    
                    if filteredTodayReminders.isEmpty {
                        VStack {
                            Spacer()
                            Text("目前沒有提醒事項")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(minHeight: 100)
                    } else {
                        // 使用 ScrollView 和 LazyVStack 展示提醒列表
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredTodayReminders) { reminder in
                                    // 使用类似 ReminderRowView 的样式
                                    ZStack {
                                        // 背景色
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(getColorForReminderType(reminder.repeatType).opacity(0.4)) // 增加不透明度
                                        
                                        // 内容
                                        HStack {
                                            // 状态指示器
                                            Circle()
                                                .fill(getColorForReminderType(reminder.repeatType))
                                                .frame(width: 14, height: 14) // 稍微增大指示器
                                                .overlay(
                                                    reminder.repeatType == "none" ?
                                                    Circle().stroke(Color.gray, lineWidth: 1) : nil
                                                )
                                                .padding(.trailing, 4)
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack {
                                                    // 前缀显示重复类型
                                                    switch reminder.repeatType {
                                                    case "daily":
                                                        Text("每日:")
                                                            .foregroundColor(.yellow)
                                                            .fontWeight(.bold)
                                                    case "weekly":
                                                        Text("每週:")
                                                            .foregroundColor(.green)
                                                            .fontWeight(.bold)
                                                    case "monthly":
                                                        Text("每月:")
                                                            .foregroundColor(.red)
                                                            .fontWeight(.bold)
                                                    default:
                                                        EmptyView()
                                                    }
                                                    
                                                    Text(reminder.title)
                                                        .font(.headline)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(getColorForReminderType(reminder.repeatType))
                                                        .strikethrough(reminder.isCompleted)
                                                }
                                                
                                                Text(formatDateTime(reminder.date))
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            // 完成/取消完成按钮
                                            Button(action: {
                                                // 处理提醒完成状态
                                                let reminderService = ReminderService(modelContext: modelContext)
                                                if reminder.isCompleted {
                                                    // 取消完成
                                                    reminder.isCompleted = false
                                                    try? modelContext.save()
                                                } else {
                                                    // 标记为完成
                                                    reminderService.completeReminder(reminder)
                                                }
                                                // 更新提醒列表
                                                checkTodayReminders()
                                            }) {
                                                Image(systemName: reminder.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                                                    .foregroundColor(reminder.isCompleted ? .orange : .green)
                                                    .font(.system(size: 24)) // 增大按钮尺寸
                                            }
                                            .buttonStyle(.plain)
                                            .help(reminder.isCompleted ? "取消完成標記" : "標記為完成")
                                            
                                            // 删除按钮
                                            Button(action: {
                                                // 删除提醒
                                                let reminderService = ReminderService(modelContext: modelContext)
                                                reminderService.deleteReminder(reminder)
                                                // 更新提醒列表
                                                checkTodayReminders()
                                            }) {
                                                Image(systemName: "trash.circle")
                                                    .foregroundColor(.red)
                                                    .font(.system(size: 24)) // 增大按钮尺寸
                                            }
                                            .buttonStyle(.plain)
                                            .help("刪除提醒")
                                        }
                                        .padding(.vertical, 10) // 增加垂直内边距
                                        .padding(.horizontal, 12)
                                        .opacity(reminder.isCompleted ? 0.7 : 1.0) // 增加已完成项的不透明度
                                    }
                                    .contextMenu {
                                        Button(action: {
                                            // 编辑提醒 - 实际应该打开编辑视图
                                            print("编辑提醒: \(reminder.title)")
                                        }) {
                                            Label("编辑", systemImage: "pencil")
                                        }
                                        
                                        if reminder.isCompleted {
                                            Button(action: {
                                                // 取消完成
                                                reminder.isCompleted = false
                                                try? modelContext.save()
                                                // 更新提醒列表
                                                checkTodayReminders()
                                            }) {
                                                Label("取消完成標記", systemImage: "arrow.uturn.backward")
                                            }
                                        } else {
                                            Button(action: {
                                                // 标记为完成
                                                let reminderService = ReminderService(modelContext: modelContext)
                                                reminderService.completeReminder(reminder)
                                                // 更新提醒列表
                                                checkTodayReminders()
                                            }) {
                                                Label("標記為完成", systemImage: "checkmark.circle")
                                            }
                                        }
                                        
                                        Button(role: .destructive, action: {
                                            // 删除提醒
                                            let reminderService = ReminderService(modelContext: modelContext)
                                            reminderService.deleteReminder(reminder)
                                            // 更新提醒列表
                                            checkTodayReminders()
                                        }) {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.horizontal)
                        }
                        .frame(width: 380, height: min(CGFloat(filteredTodayReminders.count) * 85 + 20, 450))
                    }
                }
                .padding(.bottom, 10)
            }
            
            // 搜尋按鈕
            Button(action: { toggleSearchField() }) {
                Image(systemName: showSearchField ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
            }
            .help("搜尋日記內容")
            .customCursor(.pointingHand)
            
            // 日曆按鈕
            Button(action: { switchToToday() }) {
                Image(systemName: "calendar.circle")
            }
            .help("回到今日日記")
            .customCursor(.pointingHand)
            
            // 設置按鈕
            Button(action: { showPreferences() }) {
                Image(systemName: "gear")
            }
            .help("開啟偏好設定")
            .customCursor(.pointingHand)
            
            // 幫助按鈕
            Button(action: { showHelp() }) {
                Image(systemName: "questionmark.circle")
            }
            .help("開啟使用說明")
            .customCursor(.pointingHand)
            
            // 備份按鈕（合併匯入和匯出功能）
            Menu {
                Button(action: { showDateRangeExport() }) {
                    Label("匯出備份", systemImage: "square.and.arrow.up")
                }
                
                Button(action: { showBackupSelection() }) {
                    Label("匯入備份", systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "doc.zipper")
            }
            .help("備份操作")
            .customCursor(.pointingHand)
            
            // 刪除按鈕（僅在有日記時顯示）
            if !todayDiaries.isEmpty {
                Button(action: { confirmDeleteCurrentDiary() }) {
                    Image(systemName: "minus")
                }
                .help("刪除當日日記")
                .customCursor(.pointingHand)
            }
        }
    }
    
    // 获取筛选后的今日提醒列表
    private var filteredTodayReminders: [Reminder] {
        if showCompletedReminders {
            // 显示所有提醒（包括已完成和未完成）
            return todayReminders
        } else {
            // 只显示未完成的提醒
            return todayReminders.filter { !$0.isCompleted }
        }
    }
    
    // 检查今日提醒
    private func checkTodayReminders() {
        // 获取所有提醒（不仅仅是今天的）
        let reminderService = ReminderService(modelContext: modelContext)
        // 使用getAllReminders获取所有提醒（包括已完成和未完成）
        todayReminders = reminderService.getAllReminders(includeCompleted: true)
        
        // 调试信息
        print("获取到 \(todayReminders.count) 个提醒，其中 \(todayReminders.filter { !$0.isCompleted }.count) 个未完成")
        for (index, reminder) in todayReminders.enumerated() {
            print("提醒[\(index)]: 标题=\(reminder.title), 日期=\(formatDateTime(reminder.date)), 重复类型=\(reminder.repeatType), 完成状态=\(reminder.isCompleted)")
        }
        
        // 显示提醒弹窗
        showingTodayReminders = true
    }
    
    // 根据提醒的重复类型返回颜色
    private func getColorForReminderType(_ repeatType: String) -> Color {
        switch repeatType {
        case "daily":
            return .yellow
        case "weekly":
            return .green
        case "monthly":
            return .red
        default:
            return .primary // 无重复使用主题色，确保在暗色模式下可见
        }
    }
    
    // ... existing code ...
    private func createTestReminder() {
        // 创建一个立即触发的测试提醒
        let testReminder = Reminder(
            title: "每日 test",  // 添加"每日"前缀确保被识别为每日提醒
            date: Date().addingTimeInterval(5),  // 5秒后触发
            isCompleted: false,
            repeatType: "daily"  // 明确设置为每日重复
        )
        
        print("创建测试提醒: \(testReminder.title), 日期: \(testReminder.date), 类型: \(testReminder.repeatType)")
        
        modelContext.insert(testReminder)
        try? modelContext.save()
        
        // 检查今日提醒
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            checkTodayReminders()
        }
    }
    // ... existing code ...
}

// MARK: - 新增日記視圖
struct NewDiaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var date: Date
    @State private var selectedWeather = WeatherType.sunny.rawValue
    @State private var thoughts = ""
    
    // 添加字體顏色設置
    @AppStorage("titleFontColor") private var titleFontColor: String = "Green"
    @AppStorage("contentFontColor") private var contentFontColor: String = "White"
    
    init(selectedDate: Date = Date()) {
        _date = State(initialValue: selectedDate)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 使用自定義日期選擇器
                HStack {
                    Text("日期")
                        .font(.system(size: 20))
                    Spacer()
                    CustomDatePickerView(
                        selectedDate: $date,
                        titleFontColor: titleFontColor,
                        contentFontColor: contentFontColor,
                        selectedDiary: Binding<Any?>.constant(nil)
                    )
                    .help("選擇要查看的日期")
                }
                .padding(.vertical, 5)
                
                Section("天氣") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(WeatherType.allCases, id: \.self) { weather in
                                VStack {
                                    Image(systemName: weather.icon)
                                        .font(.system(size: 22))
                                        .foregroundColor(selectedWeather == weather.rawValue ? .blue : .gray)
                                        .padding(8)
                                        .background(
                                            Circle()
                                                .fill(selectedWeather == weather.rawValue ? Color.blue.opacity(0.2) : Color.clear)
                                        )
                                    Text(weather.rawValue)
                                        .font(.system(size: 20))
                                }
                                .onTapGesture {
                                    selectedWeather = weather.rawValue
                                }
                            }
                        }
                    }
                    .frame(height: 80)
                }
                
                Section(header: Text("記事")) {
                    TextEditor(text: $thoughts)
                        .frame(height: 200)
                }
            }
            .navigationTitle("新增日誌")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let newDiary = DiaryEntry(
                            date: date,
                            thoughts: thoughts,
                            weather: WeatherType(rawValue: selectedWeather) ?? .sunny
                        )
                        modelContext.insert(newDiary)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 下面是可用的Sheet類型
enum MainContentSheetType: Identifiable {
    case settings
    
    var id: Int {
        switch self {
        case .settings: return 0
        }
    }
}

// MARK: - 類別標籤組件
struct CategoryTag: View {
    let type: DiaryEntryType
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.caption)
            
            Text(type.localizedName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isActive ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.1))
        )
        .foregroundColor(isActive ? typeColor : .secondary)
    }
    
    private var typeColor: Color {
        switch type {
        case .expense:
            return .red
        case .exercise:
            return .orange
        case .sleep:
            return .blue
        case .work:
            return .gray
        case .relationship:
            return .pink
        case .study:
            return .green
        }
    }
}

// MARK: - 預覽

// 移除了重复的ReminderListView和ReminderRowView结构体定义
// 现在使用Views/ReminderListView.swift中的定义


