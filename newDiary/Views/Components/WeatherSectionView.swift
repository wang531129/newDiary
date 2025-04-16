import SwiftUI

/// 天氣顯示視圖
struct WeatherSectionView: View {
    @Bindable var diary: DiaryEntry
    @Binding var selectedWeather: String
    @Binding var isOnline: Bool
    @Binding var isLoading: Bool
    
    let weatherService: WeatherService?
    let isToday: Bool
    let titleFontSize: Double
    let contentFontSize: Double
    let titleFontColor: String
    
    var switchToManual: () -> Void
    var saveContext: () -> Void
    
    @State private var manualLocation: String = ""
    @State private var isFormModified: Bool = false // 追蹤表單是否被修改
    @State private var isMorningSelected: Bool = true // 默認為上午
    
    // 初始化器
    init(diary: DiaryEntry,
         selectedWeather: Binding<String>,
         isOnline: Binding<Bool>,
         isLoading: Binding<Bool>,
         weatherService: WeatherService?,
         isToday: Bool,
         titleFontSize: Double,
         contentFontSize: Double,
         titleFontColor: String,
         switchToManual: @escaping () -> Void,
         saveContext: @escaping () -> Void) {
        self._diary = Bindable(wrappedValue: diary)
        self._selectedWeather = selectedWeather
        self._isOnline = isOnline
        self._isLoading = isLoading
        self.weatherService = weatherService
        self.isToday = isToday
        self.titleFontSize = titleFontSize
        self.contentFontSize = contentFontSize
        self.titleFontColor = titleFontColor
        self.switchToManual = switchToManual
        self.saveContext = saveContext
    }
    
    // 時間格式化器
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    // 用於判斷當前是上午還是下午
    private var isMorning: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("天氣")
                    .font(.system(size: titleFontSize))
                    .foregroundColor(Color.fromString(titleFontColor))
                    .fontWeight(.bold)
                
                Spacer()
                
                // 自動獲取天氣按鈕 - 只有在今天才顯示
                if isToday && weatherService != nil {
                    Button(action: {
                        // 確保有天氣服務
                        guard let weatherService = weatherService else {
                            print("Error: weatherService is nil")
                            isOnline = false
                            return
                        }
                        
                        isLoading = true
                        print("Starting weather retrieval...")
                        
                        // 使用天氣服務獲取天氣
                        Task {
                            do {
                                // 獲取當前天氣
                                print("Calling weatherService.fetchWeather()")
                                let result = try await weatherService.fetchWeather()
                                
                                // 在主線程更新UI
                                await MainActor.run {
                                    print("Weather received: \(result.type.rawValue), \(result.temp), \(result.location)")
                                    
                                    // 創建新的天氣記錄
                                    let newRecord = WeatherRecord(
                                        time: Date(),
                                        weather: result.type,
                                        temperature: result.temp,
                                        location: result.location
                                    )
                                    
                                    // 添加到記錄列表
                                    diary.weatherRecords.append(newRecord)
                                    print("Added new weather record to diary")
                                    
                                    // 更新當前狀態
                                    diary.weather = result.type
                                    diary.temperature = result.temp
                                    selectedWeather = result.type.rawValue
                                    
                                    // 保存更改
                                    saveContext()
                                    
                                    // 完成加載
                                    isLoading = false
                                    isOnline = true
                                    print("Weather retrieval completed successfully")
                                }
                            } catch {
                                // 在主線程處理錯誤
                                await MainActor.run {
                                    print("獲取天氣時出錯: \(error.localizedDescription)")
                                    print("Error details: \(error)")
                                    isLoading = false
                                    // 如果自動獲取失敗，切換到手動模式
                                    isOnline = false
                                }
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: contentFontSize * 0.8))
                                .foregroundColor(.blue)
                                .rotationEffect(Angle(degrees: isLoading ? 360 : 0))
                                .animation(isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                            
                            Text("自動獲取")
                                .font(.system(size: contentFontSize * 0.8))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                    }
                    .disabled(isLoading)
                    .customCursor(.pointingHand)
                    .help("自動獲取當前位置的天氣數據")
                }
            }
            
            HStack(spacing: 20) {
                // 上午天氣區塊
                VStack(alignment: .leading, spacing: 4) {
                    Text("上午")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let morningWeather = diary.morningWeather {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: morningWeather.weather.icon)
                                .font(.system(size: contentFontSize * 1.2))
                                .symbolRenderingMode(.multicolor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(morningWeather.weather.rawValue)
                                    .font(.system(size: contentFontSize))
                                
                                HStack {
                                    Text(morningWeather.temperature)
                                        .font(.system(size: contentFontSize))
                                    Text(timeFormatter.string(from: morningWeather.time))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(morningWeather.location ?? "未知位置")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            Text("尚無記錄")
                                .font(.system(size: contentFontSize))
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                addWeatherRecord(isMorning: true)
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                                    .font(.system(size: contentFontSize * 0.8))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                
                Spacer()
                
                // 下午天氣區塊
                VStack(alignment: .leading, spacing: 4) {
                    Text("下午")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let afternoonWeather = diary.afternoonWeather {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: afternoonWeather.weather.icon)
                                .font(.system(size: contentFontSize * 1.2))
                                .symbolRenderingMode(.multicolor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(afternoonWeather.weather.rawValue)
                                    .font(.system(size: contentFontSize))
                                
                                HStack {
                                    Text(afternoonWeather.temperature)
                                        .font(.system(size: contentFontSize))
                                    Text(timeFormatter.string(from: afternoonWeather.time))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Text(afternoonWeather.location ?? "未知位置")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            Text("尚無記錄")
                                .font(.system(size: contentFontSize))
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                addWeatherRecord(isMorning: false)
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                                    .font(.system(size: contentFontSize * 0.8))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            
            // 手動設置天氣區域 - 移除isToday限制
            if !isOnline {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("手動設置天氣")
                            .font(.system(size: titleFontSize-2))
                            .foregroundColor(Color.fromString(titleFontColor))
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // 上下午切換按鈕
                        Picker("時段", selection: $isMorningSelected) {
                            Text("上午").tag(true)
                            Text("下午").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                        .onChange(of: isMorningSelected) { oldValue, newValue in
                            // 切換時從相應記錄加載數據
                            loadCurrentPeriodWeather()
                        }
                    }
                    
                    // 將天氣、地點和溫度放在同一行
                    HStack(spacing: 10) {
                        // 天氣部分
                        Group {
                            Text("天氣")
                                .font(.system(size: contentFontSize - 2))
                                .foregroundColor(Color.fromString(titleFontColor))
                                .frame(width: 40, alignment: .leading)
                            
                            Picker("", selection: $selectedWeather) {
                                ForEach(WeatherType.allCases, id: \.rawValue) { type in
                                    HStack {
                                        Image(systemName: type.icon)
                                            .symbolRenderingMode(.multicolor)
                                        Text(type.rawValue)
                                    }
                                    .tag(type.rawValue)
                                }
                            }
                            .frame(width: 120)
                            .onChange(of: selectedWeather) { oldValue, newValue in
                                if let weatherType = WeatherType.allCases.first(where: { $0.rawValue == newValue }) {
                                    // 更新當前的天氣
                                    diary.weather = weatherType
                                    isFormModified = true
                                }
                            }
                        }
                        
                        // 地點部分
                        Group {
                            Text("地點")
                                .font(.system(size: contentFontSize - 2))
                                .foregroundColor(Color.fromString(titleFontColor))
                                .frame(width: 40, alignment: .leading)
                            
                            TextField("輸入地點", text: $manualLocation)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: contentFontSize - 2))
                                .foregroundColor(Color.primary)
                                .frame(width: 120)
                                .onChange(of: manualLocation) { oldValue, newValue in
                                    isFormModified = true
                                }
                        }
                        
                        // 溫度部分
                        Group {
                            Text("溫度")
                                .font(.system(size: contentFontSize - 2))
                                .foregroundColor(Color.fromString(titleFontColor))
                                .frame(width: 40, alignment: .leading)
                            
                            TextField("", text: $diary.temperature)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: contentFontSize))
                                .foregroundColor(Color.primary)
                                .frame(width: 80)
                                .onChange(of: diary.temperature) { oldValue, newValue in
                                    isFormModified = true
                                }
                        }
                        
                        Spacer()
                        
                        // 確認按鈕 - 根據表單狀態啓用或禁用
                        Button(action: {
                            saveManualWeather()
                            isFormModified = false
                        }) {
                            Text("確認")
                                .font(.system(size: contentFontSize))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .foregroundColor(.white)
                                .background(isFormModified ? Color.blue : Color.gray)
                                .cornerRadius(8)
                        }
                        .disabled(!isFormModified)
                    }
                }
                .padding(.top, 5)
                .onAppear {
                    // 加載初始數據
                    loadCurrentPeriodWeather()
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.textBackgroundColor)).opacity(0.4))
    }
    
    // 添加時段特定的天氣記錄
    private func addWeatherRecord(isMorning: Bool) {
        // 切換到手動模式
        if isOnline {
            switchToManual()
        }
        
        // 將isMorningSelected設置為與添加記錄的時段一致
        isMorningSelected = isMorning
        
        // 選擇當前天氣或預設晴天
        let currentWeatherType = WeatherType.allCases.first(where: { $0.rawValue == selectedWeather }) ?? .sunny
        
        // 使用日記條目的日期作為基準
        var recordTime = diary.date
        let calendar = Calendar.current
        
        // 如果是手動添加上午記錄，則設置為上午9點
        if isMorning {
            recordTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: recordTime) ?? recordTime
        }
        // 如果是手動添加下午記錄，則設置為下午15點
        else {
            recordTime = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: recordTime) ?? recordTime
        }
        
        // 創建一個新的天氣記錄，使用用戶輸入的地點（如果沒有輸入則使用默認值）
        let newRecord = WeatherRecord(
            time: recordTime,
            weather: currentWeatherType,
            temperature: diary.temperature.isEmpty ? "25°C" : diary.temperature,
            location: manualLocation.isEmpty ? "Manual Entry" : manualLocation
        )
        
        // 添加到記錄列表
        diary.weatherRecords.append(newRecord)
        
        // 更新當前的天氣
        diary.weather = currentWeatherType
        
        // 保存更改
        saveContext()
        
        // 刷新天氣記錄
        refreshWeatherRecords()
        
        // 設置表單為修改狀態以便用戶立即編輯
        isFormModified = true
    }
    
    // 保存手動設置的天氣
    private func saveManualWeather() {
        // 確保有選擇的天氣類型
        guard let weatherType = WeatherType.allCases.first(where: { $0.rawValue == selectedWeather }) else { return }
        
        // 使用日記條目的日期作為基準
        var recordTime = diary.date
        let calendar = Calendar.current
        
        // 根據用戶選擇的時段設置時間
        if isMorningSelected {
            recordTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: recordTime) ?? recordTime
        } else {
            recordTime = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: recordTime) ?? recordTime
        }
        
        // 創建一個新的天氣記錄，使用用戶輸入的地點（如果沒有輸入則使用默認值）
        let newRecord = WeatherRecord(
            time: recordTime,
            weather: weatherType,
            temperature: diary.temperature.isEmpty ? "25°C" : diary.temperature,
            location: manualLocation.isEmpty ? "Manual Entry" : manualLocation
        )
        
        // 查找並替換現有記錄，如果存在的話
        let existingRecordIndex = diary.weatherRecords.firstIndex { record in
            let recordHour = calendar.component(.hour, from: record.time)
            let isRecordMorning = recordHour < 12
            
            // 確保日期相同且是相同的時間段(上午/下午)
            return calendar.isDate(record.time, inSameDayAs: diary.date) && isRecordMorning == isMorningSelected
        }
        
        if let index = existingRecordIndex {
            // 替換現有記錄
            diary.weatherRecords[index] = newRecord
        } else {
            // 添加新記錄
            diary.weatherRecords.append(newRecord)
        }
        
        // 更新當前的天氣顯示
        if isMorningSelected && diary.morningWeather == nil {
            diary.weather = weatherType
        } else if !isMorningSelected && diary.afternoonWeather == nil {
            diary.weather = weatherType
        }
        
        // 保存更改
        saveContext()
        
        // 強制刷新顯示
        refreshWeatherRecords()
    }
    
    // 加載當前選擇時段(上午/下午)的天氣記錄
    private func loadCurrentPeriodWeather() {
        let period = isMorningSelected ? diary.morningWeather : diary.afternoonWeather
        
        if let weatherRecord = period {
            // 如果有已存在的記錄，加載其數據
            selectedWeather = weatherRecord.weather.rawValue
            manualLocation = weatherRecord.location ?? ""
            diary.temperature = weatherRecord.temperature
        } else {
            // 如果沒有記錄，使用默認值
            selectedWeather = WeatherType.sunny.rawValue
            manualLocation = ""
            diary.temperature = "25°C"
        }
        
        // 重置表單修改狀態
        isFormModified = false
    }
    
    // 確保天氣記錄刷新
    private func refreshWeatherRecords() {
        // 強制UI更新以顯示最新的天氣記錄
        let tempRecords = diary.weatherRecords
        diary.weatherRecords = []
        DispatchQueue.main.async {
            diary.weatherRecords = tempRecords
            saveContext()
        }
    }
}
