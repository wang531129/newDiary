import Foundation
import SwiftData

@Model
public final class WeatherRecord {
    public var time: Date
    public var weather: WeatherType
    public var temperature: String
    public var location: String?
    
    public init(time: Date = Date(), weather: WeatherType = .sunny, temperature: String = "", location: String? = nil) {
        self.time = time
        self.weather = weather
        self.temperature = temperature
        self.location = location
    }
    
    // 用於數據遷移的編碼方法
    enum CodingKeys: String, CodingKey {
        case time, weather, temperature, location
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.time = try container.decode(Date.self, forKey: .time)
        self.weather = try container.decode(WeatherType.self, forKey: .weather)
        self.temperature = try container.decode(String.self, forKey: .temperature)
        // 如果沒有location字段（舊數據），使用nil
        self.location = try container.decodeIfPresent(String.self, forKey: .location)
    }
} 