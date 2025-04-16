import Foundation

// MARK: - 分類類型定義
/// 定義所有可用的記錄分類
public enum DiaryEntryType: String, Codable, CaseIterable {
    case expense = "支出"
    case exercise = "運動"
    case sleep = "睡眠"
    case work = "工作"
    case relationship = "關係"
    case study = "學習"
    
    /// 本地化名称
    public var localizedName: String {
        return self.rawValue
    }
    
    /// 每種分類對應的 SF Symbols 圖標名稱
    public var icon: String {
        switch self {
        case .expense: return "dollarsign.circle"
        case .exercise: return "figure.run"
        case .sleep: return "bed.double"
        case .work: return "briefcase"
        case .relationship: return "person.2"
        case .study: return "book"
        }
    }
    
    /// 每種分類的預定義選項
    var categories: [String] {
        switch self {
        case .expense:
            return ["飲食(早)", "飲食(中)", "飲食(晚)","水果", "家庭用品", "個人用品",
                   "稅金", "孝親費","水電瓦斯費", "贈予", "紅白包", "交通費"]
        case .exercise:
            return ["肩", "背", "胸", "腿", "手", "核心"]
        case .work:
            return ["菌檢", "儀校", "代工","家事", "協助", "衛生檢查", "教育訓練"]
        case .relationship:
            return ["視訊", "短信", "閒聊","會面", "聚餐", "探視"]
        case .study:
            return ["書籍", "電媒", "語言", "健身","技能", "修養"]
        case .sleep:
            return ["0", "1", "2", "3", "4", "5", "6"]
        }
    }
} 
