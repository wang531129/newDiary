import Foundation
import SwiftData

@Model
public final class DiaryEntry {
    public var date: Date
    public var thoughts: String
    public var weather: WeatherType
    public var temperature: String
    public var weatherRecords: [WeatherRecord]
    
    // 類別記錄
    @Relationship(deleteRule: .cascade) public var expenses: [CategoryEntry]
    @Relationship(deleteRule: .cascade) public var exercises: [CategoryEntry]
    @Relationship(deleteRule: .cascade) public var sleeps: [CategoryEntry]
    @Relationship(deleteRule: .cascade) public var works: [CategoryEntry]
    @Relationship(deleteRule: .cascade) public var relationships: [CategoryEntry]
    @Relationship(deleteRule: .cascade) public var studies: [CategoryEntry]
    
    // 提醒事項
    @Relationship(deleteRule: .cascade) public var reminders: [ReminderItem]
    
    public init(
        date: Date = Date(),
        thoughts: String = "",
        weather: WeatherType = .sunny,
        temperature: String = "",
        weatherRecords: [WeatherRecord] = []
    ) {
        self.date = date
        self.thoughts = thoughts
        self.weather = weather
        self.temperature = temperature
        self.weatherRecords = weatherRecords
        self.expenses = []
        self.exercises = []
        self.sleeps = []
        self.works = []
        self.relationships = []
        self.studies = []
        self.reminders = []
    }
    
    // 從備份創建日記條目的靜態方法
    public static func createFromBackup(
        id: UUID,
        date: Date,
        thoughts: String,
        weather: WeatherType,
        temperature: String,
        weatherRecords: [WeatherRecord] = [],
        expenses: [CategoryEntry] = [],
        exercises: [CategoryEntry] = [],
        sleeps: [CategoryEntry] = [],
        works: [CategoryEntry] = [],
        relationships: [CategoryEntry] = [],
        studies: [CategoryEntry] = []
    ) -> DiaryEntry {
        // 創建基本日記條目
        let entry = DiaryEntry(
            date: date,
            thoughts: thoughts,
            weather: weather,
            temperature: temperature,
            weatherRecords: []
        )
        
        // 安全添加天氣記錄
        for record in weatherRecords {
            entry.weatherRecords.append(record)
        }
        
        // 不在這裡添加類別條目，而是由調用者負責
        // 這樣可以避免在此方法中出現 SwiftData 相關錯誤
        
        return entry
    }
    
    // 獲取最新的上午天氣記錄
    public var morningWeather: WeatherRecord? {
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        
        return weatherRecords
            .filter { $0.time < noon }
            .sorted { $0.time > $1.time }
            .first
    }
    
    // 獲取最新的下午天氣記錄
    public var afternoonWeather: WeatherRecord? {
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
        
        return weatherRecords
            .filter { $0.time >= noon }
            .sorted { $0.time > $1.time }
            .first
    }
} 