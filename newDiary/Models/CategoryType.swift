import Foundation

/// 分類類型枚舉
enum CategoryType: String, Codable, CaseIterable, Identifiable {
    // MARK: - 枚舉類型
    
    /// 支出
    case expense = "支出"
    
    /// 運動
    case exercise = "運動"
    
    /// 睡眠
    case sleep = "睡眠"
    
    /// 工作
    case work = "工作"
    
    /// 人際關係
    case relationship = "人際關係"
    
    /// 學習
    case study = "學習"
    
    // MARK: - Identifiable 協議
    var id: String { self.rawValue }
    
    // MARK: - 計算屬性
    
    /// 獲取圖標名稱
    var icon: String {
        switch self {
        case .expense:
            return "dollarsign.circle"
        case .exercise:
            return "figure.run"
        case .sleep:
            return "bed.double"
        case .work:
            return "briefcase"
        case .relationship:
            return "person.2"
        case .study:
            return "book"
        }
    }
    
    /// 獲取單位
    var unit: String {
        switch self {
        case .expense:
            return "元"
        case .exercise:
            return "分鐘"
        case .sleep:
            return "小時"
        case .work:
            return "小時"
        case .relationship:
            return "次"
        case .study:
            return "小時"
        }
    }
    
    /// 獲取預定義的類別列表
    var categories: [String] {
        switch self {
        case .expense:
            return ["飲食", "交通", "住宿", "購物", "娛樂", "醫療", "其他"]
        case .exercise:
            return ["跑步", "健身", "游泳", "騎行", "瑜伽", "球類", "其他"]
        case .sleep:
            return ["午睡", "晚睡", "其他"]
        case .work:
            return ["會議", "編碼", "設計", "文檔", "客戶溝通", "其他"]
        case .relationship:
            return ["家人", "朋友", "同事", "戀人", "其他"]
        case .study:
            return ["閱讀", "課程", "練習", "研究", "其他"]
        }
    }
}
