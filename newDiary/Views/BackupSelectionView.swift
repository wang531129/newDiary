import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// 備份選擇視圖
struct BackupSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var backupFiles: [URL] = []
    @State private var selectedBackupURL: URL? = nil
    @State private var isLoading = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false
    @State private var lastExportedURL: URL? = nil
    @State private var isDropTargetActive = false
    
    // 使用AppStorage訪問全局設定的字體大小和顏色
    @AppStorage("titleFontSize") private var titleFontSize: Double = 22
    @AppStorage("contentFontSize") private var contentFontSize: Double = 16
    @AppStorage("titleFontColor") private var titleFontColor: String = "Orange"
    @AppStorage("contentFontColor") private var contentFontColor: String = "White"
    
    var body: some View {
        VStack(spacing: 15) {
            Text("選擇備份檔案")
                .font(.system(size: CGFloat(titleFontSize)))
                .foregroundColor(Color.fromString(titleFontColor))
                .padding(.top, 10)
            
            // 操作按鈕
            HStack {
                Button(action: {
                    selectedBackupURL = nil
                    refreshBackupFiles()
                }) {
                    Label("刷新列表", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    browseForBackupFile()
                }) {
                    Label("瀏覽檔案...", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            if isLoading {
                ProgressView("正在載入備份檔案...")
                    .padding()
            } else if backupFiles.isEmpty {
                // 拖放區域
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundColor(isDropTargetActive ? .blue : .gray)
                        .background(isDropTargetActive ? Color.blue.opacity(0.1) : Color.clear)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 40))
                            .foregroundColor(isDropTargetActive ? .blue : .gray)
                        
                        Text("拖放日記備份檔案到此處")
                            .font(.system(size: CGFloat(contentFontSize)))
                            .foregroundColor(isDropTargetActive ? .blue : .secondary)
                        
                        Text("或者從上方瀏覽選擇檔案")
                            .font(.system(size: CGFloat(contentFontSize) - 2))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else {
                // 顯示備份文件列表（加入拖放支持）
                List(backupFiles, id: \.path) { url in
                    BackupFileRow(
                        url: url,
                        isSelected: selectedBackupURL?.path == url.path
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedBackupURL = url
                    }
                }
                .overlay(
                    Group {
                        if isDropTargetActive {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .foregroundColor(.blue)
                                .background(Color.blue.opacity(0.1))
                        }
                    }
                )
                .frame(maxHeight: .infinity)
            }
            
            // 底部操作區域
            HStack {
                Button(action: {
                    print("取消按鈕被點擊，準備關閉視窗")
                    // 使用更強的方式確保視窗關閉
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }) {
                    Text("取消")
                        .frame(width: 80)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    restoreBackup()
                }) {
                    Text("恢復備份")
                        .frame(width: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedBackupURL == nil)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .frame(width: 400, height: 500)
        .onAppear {
            refreshBackupFiles()
        }
        .onDrop(of: [UTType.json.identifier], isTargeted: $isDropTargetActive) { providers in
            handleDrop(providers: providers)
            return true
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("確定")) {
                    // 如果是恢復成功的情況，關閉視窗
                    if alertTitle == "恢復成功" {
                        print("恢復成功後關閉對話框，準備關閉視窗")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.dismiss()
                        }
                    }
                }
            )
        }
    }
    
    // 處理檔案拖放
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.json.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.json.identifier, options: nil) { item, error in
                    guard error == nil else {
                        DispatchQueue.main.async {
                            self.alertTitle = "檔案拖放失敗"
                            self.alertMessage = "無法讀取拖放的檔案：\(error?.localizedDescription ?? "未知錯誤")"
                            self.showingAlert = true
                        }
                        return
                    }
                    
                    if let url = item as? URL {
                        // 檢查是否是有效的備份檔案名稱格式
                        let filename = url.lastPathComponent
                        if filename.starts(with: "diary_backup_") && url.pathExtension == "json" {
                            DispatchQueue.main.async {
                                self.selectedBackupURL = url
                                // 如果列表中沒有這個檔案，添加到列表前面
                                if !self.backupFiles.contains(where: { $0.path == url.path }) {
                                    self.backupFiles.insert(url, at: 0)
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.alertTitle = "無效的備份檔案"
                                self.alertMessage = "請拖放以 'diary_backup_' 開頭的 JSON 備份檔案。"
                                self.showingAlert = true
                            }
                        }
                    }
                }
                return true
            }
        }
        return false
    }
    
    // 重新載入備份檔案列表
    private func refreshBackupFiles() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let files = MainContentView.findLocalBackupsStatic()
            
            DispatchQueue.main.async {
                backupFiles = files
                isLoading = false
            }
        }
    }
    
    // 瀏覽選擇備份檔案
    private func browseForBackupFile() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.title = "選擇日記備份檔案"
        openPanel.allowedFileTypes = ["json"]  // 使用字符串定義檔案類型而不是 UTType
        openPanel.prompt = "選擇"
        
        let response = openPanel.runModal()
        
        if response == NSApplication.ModalResponse.OK, let url = openPanel.url {
            // 檢查是否是有效的備份檔案名稱格式
            let filename = url.lastPathComponent
            if filename.starts(with: "diary_backup_") && url.pathExtension == "json" {
                selectedBackupURL = url
                
                // 如果列表中沒有這個檔案，添加到列表前面
                if !backupFiles.contains(where: { $0.path == url.path }) {
                    backupFiles.insert(url, at: 0)
                }
            } else {
                alertTitle = "無效的備份檔案"
                alertMessage = "請選擇以 'diary_backup_' 開頭的 JSON 備份檔案。"
                showingAlert = true
            }
        }
    }
    
    // 恢復備份
    private func restoreBackup() {
        guard let url = selectedBackupURL else { return }
        
        print("開始準備恢復備份：\(url.path)")
        
        // 確保在主線程上顯示對話框
        DispatchQueue.main.async {
            // 確認對話框
            let alert = NSAlert()
            alert.messageText = "確認恢復備份"
            alert.informativeText = "智能恢復模式：\n\n· 僅替換備份中包含的日期資料\n· 不在備份日期範圍內的資料將被保留\n· 重複日期的資料將被覆蓋\n· 缺少的日期會被新增\n\n確定要繼續嗎？"
            alert.addButton(withTitle: "繼續")
            alert.addButton(withTitle: "取消")
            alert.alertStyle = .warning
            
            let response = alert.runModal()
            print("用戶對恢復確認的響應：\(response.rawValue)")
            
            if response == NSApplication.ModalResponse.alertFirstButtonReturn {
                // 用戶確認恢復
                print("用戶確認恢復，開始加載備份文件")
                let result = BackupManager.shared.loadBackup(from: url)
                
                switch result {
                case .success(let backup):
                    // 嘗試恢復數據
                    print("備份文件加載成功，開始恢復數據")
                    self.restoreFromBackup(backup, sourceURL: url)
                    
                case .failure(let error):
                    // 處理錯誤
                    print("備份文件加載失敗：\(error.localizedDescription)")
                    self.alertTitle = "恢復失敗"
                    self.alertMessage = "讀取備份檔案時出錯：\(error.localizedDescription)"
                    self.showingAlert = true
                }
            } else {
                // 用戶取消操作
                print("用戶取消了恢復操作")
            }
        }
    }
    
    // 從備份數據恢復
    private func restoreFromBackup(_ backup: DiaryBackup, sourceURL: URL) {
        print("開始執行智能恢復備份操作")
        
        do {
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
            print("備份數據日期範圍：\(startDate) 到 \(endDate)")
            
            // 獲取所有現有條目
            var allEntriesDescriptor = FetchDescriptor<DiaryEntry>()
            let allExistingEntries = try modelContext.fetch(allEntriesDescriptor)
            print("找到 \(allExistingEntries.count) 個現有日記條目")
            
            // 創建一個字典來儲存現有條目，以日期為鍵
            let calendar = Calendar.current
            var existingEntriesByDay = [String: DiaryEntry]()
            
            // 用於確定日期的函數
            func dateKey(from date: Date) -> String {
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                return "\(components.year!)-\(components.month!)-\(components.day!)"
            }
            
            // 收集所有現有條目，按日期分類
            for entry in allExistingEntries {
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
            
            print("需要刪除的現有條目數：\(entriesToDelete.count)")
            print("需要處理的日期數：\(daysToProcess.count)")
            
            // 刪除在備份範圍內的現有條目
            for entry in entriesToDelete {
                modelContext.delete(entry)
            }
            
            // 保存刪除操作
            try modelContext.save()
            print("成功刪除選定的現有條目")
            
            // 從備份創建新條目
            var successCount = 0
            var failureCount = 0
            
            // 批量處理備份條目
            let batchSize = 5 // 每批處理的條目數量
            let daysArray = Array(daysToProcess)
            let totalDays = daysArray.count
            
            for batchIndex in stride(from: 0, to: totalDays, by: batchSize) {
                // 確定當前批次的結束索引
                let endIndex = min(batchIndex + batchSize, totalDays)
                let batchDays = daysArray[batchIndex..<endIndex]
                
                print("處理批次 \(batchIndex/batchSize + 1)，日期 \(batchIndex+1) 到 \(endIndex)")
                
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
                                temperature: weatherBackup.temperature
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
                        print("恢復單個日誌條目時出錯: \(error)")
                        failureCount += 1
                    }
                }
                
                // 每批次處理完保存一次上下文
                try modelContext.save()
                print("批次 \(batchIndex/batchSize + 1) 已保存")
            }
            
            // 最後再保存一次確保所有數據都被寫入
            try modelContext.save()
            print("成功保存 \(successCount) 個恢復的條目，\(allExistingEntries.count - entriesToDelete.count) 個現有條目被保留")
            
            // 顯示成功訊息
            alertTitle = "恢復成功"
            
            // 格式化日期範圍
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy/MM/dd"
            let formattedStartDate = dateFormatter.string(from: startDate)
            let formattedEndDate = dateFormatter.string(from: endDate)
            
            alertMessage = "已成功恢復 \(successCount) 篇日記" +
                (failureCount > 0 ? "，\(failureCount) 篇恢復失敗" : "") +
                "，\(allExistingEntries.count - entriesToDelete.count) 篇現有日記被保留" +
                "\n\n備份日期範圍：\(formattedStartDate) 至 \(formattedEndDate)" +
                "\n備份來源：\n\(sourceURL.path)"
            lastExportedURL = sourceURL
            
            // 顯示自定義對話框
            showingAlert = true
            
        } catch {
            // 處理錯誤
            print("恢復過程中出錯：\(error.localizedDescription)")
            alertTitle = "恢復失敗"
            alertMessage = "恢復過程中出錯：\(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    // 從備份數據創建分類條目
    private func createCategoryEntry(_ backup: DiaryBackup.CategoryBackupEntry, type: DiaryEntryType) -> CategoryEntry {
        // 先創建一個安全的數字值
        let safeNumber = max(0, min(backup.number, Double.greatestFiniteMagnitude))
        
        // 使用安全的方法創建條目
        let entry = CategoryEntry(
            name: backup.name,
            number: safeNumber,
            notes: backup.notes,
            category: backup.category,
            type: type,
            date: Date() // 添加當前日期
        )
        
        // 將條目添加到模型上下文
        modelContext.insert(entry)
        
        return entry
    }
}

/// 備份項目視圖
struct BackupItemView: View {
    let backupURL: URL
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(backupURL.lastPathComponent)
                    .font(.headline)
                
                if let date = getFileDate() {
                    Text("創建於：\(formatDate(date))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let size = getFileSize() {
                    Text("文件大小：\(formatFileSize(size))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.title)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
    }
    
    // 獲取文件創建日期
    private func getFileDate() -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: backupURL.path)
            return attributes[.creationDate] as? Date
        } catch {
            print("無法獲取文件日期：\(error)")
            return nil
        }
    }
    
    // 獲取文件大小
    private func getFileSize() -> Int? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: backupURL.path)
            return attributes[.size] as? Int
        } catch {
            print("無法獲取文件大小：\(error)")
            return nil
        }
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // 格式化文件大小
    private func formatFileSize(_ size: Int) -> String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: Int64(size))
    }
}

// 備份文件行
struct BackupFileRow: View {
    let url: URL
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // 顯示文件名
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                // 顯示文件路徑
                Text(url.deletingLastPathComponent().path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // 顯示文件修改日期
                if let modDate = getModificationDate() {
                    Text("修改日期：\(formatDate(modDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 5)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(5)
    }
    
    // 獲取文件修改日期
    private func getModificationDate() -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
