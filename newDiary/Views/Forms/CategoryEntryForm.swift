import SwiftUI
import SwiftData
import Foundation

struct CategoryEntryForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let type: DiaryEntryType
    let diary: DiaryEntry
    var editingEntry: CategoryEntry? = nil
    
    @State private var name = ""
    @State private var category = ""
    @State private var number: Double = 0
    @State private var numberString = "0"
    @State private var notes = ""
    @State private var showNumberError = false
    @State private var showingCategoryPicker = false
    @FocusState private var isCategoryFocused: Bool
    
    // 新增的狀態變數，用於自動完成功能
    @State private var suggestions: [String] = []
    @State private var showingSuggestions = false
    @State private var selectedSuggestionIndex = 0
    @Query private var allDiaries: [DiaryEntry]
    
    // 添加新的狀態變量用於類別自動完成
    @State private var categorySuggestions: [String] = []
    @State private var showingCategorySuggestions = false
    @State private var selectedCategorySuggestionIndex = 0
    
    init(type: DiaryEntryType, diary: DiaryEntry, editingEntry: CategoryEntry? = nil) {
        print("Debug - CategoryEntryForm init with type: \(type.rawValue), editingEntry: \(editingEntry?.type.rawValue ?? "nil")")
        
        self.type = type
        self.diary = diary
        self.editingEntry = editingEntry
        
        // 如果在編輯模式，確保我們使用條目的實際類型來初始化表單
        // 即使傳入的type與entry.type不同
        let actualType = editingEntry?.type ?? type
        if editingEntry != nil && actualType != type {
            print("Debug - WARNING: Mismatch between passed type (\(type.rawValue)) and entry type (\(actualType.rawValue))")
            print("Debug - Using entry's actual type: \(actualType.rawValue)")
        }
        
        let initialName = editingEntry?.name ?? ""
        let initialCategory = editingEntry?.category ?? ""
        let initialNumber = editingEntry?.number ?? 0
        let initialNotes = editingEntry?.notes ?? ""
        
        _name = State(initialValue: initialName)
        _category = State(initialValue: initialCategory)
        _number = State(initialValue: initialNumber)
        
        // 如果是時間相關項目，格式化為h:mm格式
        if  editingEntry != nil,
           (actualType == .exercise || actualType == .sleep || actualType == .work || 
            actualType == .relationship || actualType == .study) {
            _numberString = State(initialValue: formatMinutesToTimeString(Int(initialNumber)))
        } else {
            _numberString = State(initialValue: String(format: "%.0f", initialNumber))
        }
        
        _notes = State(initialValue: initialNotes)
        
        print("Debug - CategoryEntryForm initialized with formTitle: \(editingEntry == nil ? "新增\(actualType.rawValue)記錄" : "編輯\(actualType.rawValue)記錄")")
    }
    
    private func validateAndUpdateNumber(_ newValue: String) {
        // 移除小數點
        let sanitizedInput = newValue.replacingOccurrences(of: ".", with: "")
        
        // 嘗試解析為數字
        if let parsedNumber = Double(sanitizedInput) {
            // 檢查數字範圍
            let isInValidRange = parsedNumber >= 0 && parsedNumber <= 999999
            
            if isInValidRange {
                // 更新狀態
                number = parsedNumber
                numberString = String(format: "%.0f", parsedNumber)
                showNumberError = false
                return
            }
        }
        
        // 如果解析失敗或超出範圍，顯示錯誤
        showNumberError = true
    }
    
    // 獲取以前輸入過的名稱列表
    private func getPreviousNames() -> [String] {
        // 創建一個集合來儲存不重複的名稱
        var names = Set<String>()
        
        // 根據當前類型獲取對應的條目集合
        for diary in allDiaries {
            // 獲取特定類型的條目陣列
            let entries = getEntriesForType(from: diary)
            
            // 收集有效的名稱
            for entry in entries {
                if !entry.name.isEmpty {
                    names.insert(entry.name)
                }
            }
        }
        
        // 轉換為排序的陣列並返回
        return Array(names).sorted()
    }
    
    // 從日記中獲取特定類型的條目
    private func getEntriesForType(from diary: DiaryEntry) -> [CategoryEntry] {
        switch type {
        case .expense: return diary.expenses
        case .exercise: return diary.exercises
        case .sleep: return diary.sleeps
        case .work: return diary.works
        case .relationship: return diary.relationships
        case .study: return diary.studies
        }
    }
    
    // 處理名稱變化
    private func handleNameChange(_ newValue: String) {
        name = newValue
        
        if !newValue.isEmpty {
            // 获取所有之前的名称
            let previousNames = getPreviousNames()
            
            // 过滤匹配的建议
            let filteredSuggestions = previousNames.filter { 
                $0.localizedCaseInsensitiveContains(newValue) 
            }
            
            // 更新状态
            suggestions = filteredSuggestions
            showingSuggestions = !filteredSuggestions.isEmpty
        } else {
            showingSuggestions = false
        }
    }
    
    // 處理時間字符串變化
    private func handleTimeStringChange(_ newValue: String) {
        // 嘗試直接將輸入解析為分鐘數
        if let minutes = Int(newValue.trimmingCharacters(in: .whitespaces)), minutes >= 0 {
            // 直接使用分鐘數
            number = Double(minutes)
            numberString = newValue
            showNumberError = false
            return
        }
        
        // 如果不是純分鐘數，嘗試解析 h:mm 格式
        let components = newValue.split(separator: ":")
        
        // 檢查是否符合 h:mm 格式
        if components.count == 2,
           let hours = Int(components[0]),
           let minutes = Int(components[1]),
           hours >= 0 && minutes >= 0 && minutes < 60 {
            // 計算總分鐘數並更新狀態
            let totalMinutes = hours * 60 + minutes
            number = Double(totalMinutes)
            numberString = newValue
            showNumberError = false
            return
        } else if components.count == 1,
                  let hours = Int(components[0]),
                  hours >= 0 {
            // 處理 "小時:" 格式（只有小時部分）
            let totalMinutes = hours * 60
            number = Double(totalMinutes)
            numberString = newValue
            showNumberError = false
            return
        }
        
        // 如果所有驗證都失敗，顯示錯誤
        showNumberError = true
    }
    
    // 獲取以前輸入過的類別列表
    private func getPreviousCategories() -> [String] {
        // 創建一個集合來儲存不重複的類別
        var categories = Set<String>()
        
        // 添加預定義的類別
        for category in type.categories {
            categories.insert(category)
        }
        
        // 根據當前類型獲取對應的條目集合
        for diary in allDiaries {
            // 獲取特定類型的條目陣列
            let entries = getEntriesForType(from: diary)
            
            // 收集有效的類別
            for entry in entries {
                if !entry.category.isEmpty {
                    categories.insert(entry.category)
                }
            }
        }
        
        // 轉換為排序的陣列並返回
        return Array(categories).sorted()
    }
    
    // 處理類別變化
    private func handleCategoryChange(_ newValue: String) {
        category = newValue
        
        if !newValue.isEmpty {
            // 获取所有之前的類別
            let previousCategories = getPreviousCategories()
            
            // 过滤匹配的建议
            let filteredSuggestions = previousCategories.filter { 
                $0.localizedCaseInsensitiveContains(newValue) 
            }
            
            // 更新状态
            categorySuggestions = filteredSuggestions
            showingCategorySuggestions = !filteredSuggestions.isEmpty
        } else {
            showingCategorySuggestions = false
        }
    }
    
    private func saveEntry() {
        let entry: CategoryEntry
        
        if let editingEntry = editingEntry {
            // 更新現有條目
            entry = editingEntry
            entry.name = name
            entry.category = category
            entry.number = number
            entry.notes = notes
        } else {
            // 創建新條目
            entry = CategoryEntry(name: name, number: number, notes: notes, category: category, type: type)
            
            // 將條目添加到日記的相應集合中
            switch type {
            case .expense: diary.expenses.append(entry)
            case .exercise: diary.exercises.append(entry)
            case .sleep: diary.sleeps.append(entry)
            case .work: diary.works.append(entry)
            case .relationship: diary.relationships.append(entry)
            case .study: diary.studies.append(entry)
            }
        }
        
        dismiss()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            Text(nameLabel)
                                .foregroundColor(.secondary)
                                .font(.system(size: 20))
                        }
                        
                        TextField("", text: $name)
                            .font(.system(size: 16))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: name) { _, newValue in
                                handleNameChange(newValue)
                            }
                        
                        if showingSuggestions {
                            ScrollView {
                                // 計算合適的高度
                                let maxHeight: CGFloat = 150
                                let itemHeight: CGFloat = 35
                                let calculatedHeight = min(CGFloat(suggestions.count) * itemHeight, maxHeight)
                                
                                // 創建邊框樣式
                                let borderStyle = RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(suggestions, id: \.self) { suggestion in
                                        SuggestionItemView(suggestion: suggestion) { selectedSuggestion in
                                            name = selectedSuggestion
                                            showingSuggestions = false
                                        }
                                    }
                                }
                                .padding(5)
                                .frame(height: calculatedHeight)
                                .background(borderStyle)
                                .transition(.opacity)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.blue)
                                .font(.system(size: 20))
                            Text(categoryLabel)
                                .foregroundColor(.secondary)
                                .font(.system(size: 20))
                        }
                        
                        HStack {
                            TextField("", text: $category)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 16))
                                .focused($isCategoryFocused)
                                .onChange(of: category) { _, newValue in
                                    handleCategoryChange(newValue)
                                }
                            
                            if type.categories.isEmpty {
                                Button(action: { showingCategoryPicker = false }) {
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                }
                                .disabled(true)
                                .buttonStyle(BorderlessButtonStyle())
                            } else {
                                Button(action: { showingCategoryPicker.toggle() }) {
                                    Image(systemName: showingCategoryPicker ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        
                        if showingCategorySuggestions {
                            ScrollView {
                                // 計算合適的高度
                                let maxHeight: CGFloat = 150
                                let itemHeight: CGFloat = 35
                                let calculatedHeight = min(CGFloat(categorySuggestions.count) * itemHeight, maxHeight)
                                
                                // 創建邊框樣式
                                let borderStyle = RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(categorySuggestions, id: \.self) { suggestion in
                                        SuggestionItemView(suggestion: suggestion) { selectedSuggestion in
                                            category = selectedSuggestion
                                            showingCategorySuggestions = false
                                            // 選擇後自動關閉預定義選擇器
                                            showingCategoryPicker = false
                                        }
                                    }
                                }
                                .padding(5)
                                .frame(height: calculatedHeight)
                                .background(borderStyle)
                                .transition(.opacity)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 顯示預定義類別選擇器
                if showingCategoryPicker && !type.categories.isEmpty {
                    // 提前準備計算屬性
                    let pickerHeight = min(CGFloat(type.categories.count) * 40, 200)
                    let borderStyle = RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(type.categories, id: \.self) { option in
                                // 確定是否為最後一項
                                let isLast = option == type.categories.last
                                let isOptionSelected = category == option
                                
                                CategoryPickerItemView(
                                    option: option,
                                    isSelected: isOptionSelected,
                                    isLast: isLast
                                ) { selectedOption in
                                    category = selectedOption
                                    showingCategoryPicker = false
                                    // 選擇後自動關閉自動完成建議
                                    showingCategorySuggestions = false
                                }
                            }
                        }
                    }
                    .frame(height: pickerHeight)
                    .background(borderStyle)
                    .padding(.top, 5)
                }
                
                Section {
                    NumberInputSection(
                        type: type,
                        numberString: $numberString,
                        showNumberError: $showNumberError,
                        shouldShowNumberInput: shouldShowNumberInput,
                        validateAndUpdateNumber: validateAndUpdateNumber,
                        handleTimeStringChange: handleTimeStringChange
                    )
                }
                
                NotesSection(notes: $notes)
            }
            .navigationTitle(formTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveEntry()
                    }
                    .disabled(isSaveButtonDisabled)
                }
            }
        }
    }
    
    // 獲取適合當前類型的標籤
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
    
    // 在navigationTitle前添加计算属性
    var formTitle: String {
        let actualType = editingEntry?.type ?? type
        return editingEntry == nil ? "新增\(actualType.rawValue)記錄" : "編輯\(actualType.rawValue)記錄"
    }
    
    // 判断保存按钮是否禁用
    var isSaveButtonDisabled: Bool {
        return name.isEmpty || showNumberError
    }
    
    // 确定是否展示数字输入框
    var shouldShowNumberInput: Bool {
        return type == .expense
    }
}

private struct NotesSection: View {
    @Binding var notes: String
    
    var body: some View {
        Section {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "text.bubble.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                    Text("備注")
                        .foregroundColor(.secondary)
                        .font(.system(size: 20))
                }
                
                TextEditor(text: $notes)
                    .font(.system(size: 16))
                    .frame(height: 100)
                    .cornerRadius(4)
            }
            .padding(.vertical, 4)
        }
    }
}

// 在 SuggestionItemView 中整理相關代碼
private struct SuggestionItemView: View {
    let suggestion: String
    let onTap: (String) -> Void
    
    var body: some View {
        let backgroundShape = RoundedRectangle(cornerRadius: 5)
            .fill(Color.blue.opacity(0.1))
        
        Text(suggestion)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundShape)
            .onTapGesture {
                onTap(suggestion)
            }
    }
}

// 定義一個用於分類項目的子視圖
private struct CategoryPickerItemView: View {
    let option: String
    let isSelected: Bool
    let isLast: Bool
    let onSelect: (String) -> Void
    
    var body: some View {
        // 創建背景顏色
        let backgroundColor = isSelected ? Color.blue.opacity(0.1) : Color.clear
        
        VStack(spacing: 0) {
            HStack {
                Text(option)
                    .font(.system(size: 16))
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .onTapGesture {
                onSelect(option)
            }
            
            // 添加分隔線（如果不是最後一項）
            if !isLast {
                Divider()
                    .padding(.horizontal, 5)
            }
        }
    }
}

// 創建一個用於數字輸入區域的子視圖
private struct NumberInputSection: View {
    let type: DiaryEntryType
    @Binding var numberString: String
    @Binding var showNumberError: Bool
    let shouldShowNumberInput: Bool
    let validateAndUpdateNumber: (String) -> Void
    let handleTimeStringChange: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading) {
            // 輸入標籤
            HStack {
                Image(systemName: numberIcon)
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
                Text(numberLabel)
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
            }
            
            // 根據類型選擇不同的輸入方式
            if shouldShowNumberInput {
                // 金額輸入 - 適用於 macOS 的實現
                TextField("", text: $numberString)
                    .font(.system(size: 16))
                    // 在 macOS 中沒有 keyboardType
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: numberString) { _, newValue in
                        validateAndUpdateNumber(newValue)
                    }
            } else {
                // 時間輸入
                TextField("", text: $numberString)
                    .font(.system(size: 16))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: numberString) { _, newValue in
                        handleTimeStringChange(newValue)
                    }
                    .background(
                        colorScheme == .dark ? Color.black.opacity(0.3) : Color.white
                    )
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    )
                    .help("請使用小時:分鐘格式，例如 1:30 表示1小時30分鐘，或直接輸入分鐘數，例如 30 表示30分鐘")
            }
            
            // 錯誤信息
            if showNumberError {
                ErrorMessageView(type: type)
            }
        }
        .padding(.vertical, 4)
    }
    
    // 獲取數字輸入區域的圖標
    private var numberIcon: String {
        switch type {
        case .expense: return "dollarsign.circle.fill"
        case .exercise, .sleep, .work, .relationship, .study: return "clock.fill"
        }
    }
    
    // 獲取數字輸入區域的標籤
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
}

// 錯誤信息視圖
private struct ErrorMessageView: View {
    let type: DiaryEntryType
    
    var body: some View {
        let errorMessage = type == .expense ? 
            "請輸入有效的數字" : 
            "請輸入有效的時間格式，如 1:30，或直接輸入分鐘數"
        
        Text(errorMessage)
            .foregroundColor(.red)
            .font(.caption)
            .padding(.top, 2)
    }
} 
