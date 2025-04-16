import Foundation
import SwiftUI

/// 定義所有可用的天氣類型
public enum WeatherType: String, Codable, CaseIterable {
    case sunny = "晴天"
    case cloudy = "多雲"
    case rainy = "雨天"
    case snowy = "雪天"
    
    /// 每種天氣對應的 SF Symbols 圖標名稱
    public var icon: String {
        switch self {
        case .sunny:
            return "sun.max.fill"
        case .cloudy:
            return "cloud.fill"
        case .rainy:
            return "cloud.rain.fill"
        case .snowy:
            return "cloud.snow.fill"
        }
    }
    
    public static var allCases: [WeatherType] {
        return [.sunny, .cloudy, .rainy, .snowy]
    }
} 