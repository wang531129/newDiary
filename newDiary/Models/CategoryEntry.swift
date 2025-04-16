import Foundation
import SwiftData
import Observation

@Model
public final class CategoryEntry {
    public var name: String
    @Attribute private var _number: Double
    public var notes: String
    public var category: String
    public var type: DiaryEntryType
    public var date: Date
    
    public init(name: String = "", number: Double = 0, notes: String = "", category: String = "", type: DiaryEntryType, date: Date = Date()) {
        self.name = name
        // 進行數值檢查，確保 number 在合理範圍內
        let safeNumber = max(0, min(number, Double.greatestFiniteMagnitude))
        self._number = safeNumber
        self.notes = notes
        self.category = category
        self.type = type
        self.date = date
    }
    
    // 安全訪問 number 屬性的getter
    public var number: Double {
        get {
            // 使用預設值提供一個安全的回退機制
            return _number
        }
        set {
            // 進行數值檢查，確保 number 在合理範圍內
            let safeValue = max(0, min(newValue, Double.greatestFiniteMagnitude))
            _number = safeValue
        }
    }
    
    // 從備份數據安全創建實例的靜態方法
    public static func createFromBackup(name: String, number: Double, notes: String, category: String, type: DiaryEntryType, date: Date = Date()) -> CategoryEntry {
        let entry = CategoryEntry(
            name: name,
            number: number,
            notes: notes,
            category: category,
            type: type,
            date: date
        )
        return entry
    }
} 