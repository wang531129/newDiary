import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var useDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(useDarkMode, forKey: "useDarkMode")
        }
    }
    
    @Published var titleFontSize: Double {
        didSet {
            UserDefaults.standard.set(titleFontSize, forKey: "titleFontSize")
        }
    }
    
    @Published var contentFontSize: Double {
        didSet {
            UserDefaults.standard.set(contentFontSize, forKey: "contentFontSize")
        }
    }
    
    @Published var templateTitle: String {
        didSet {
            UserDefaults.standard.set(templateTitle, forKey: "templateTitle")
        }
    }
    
    @Published var templateContent: String {
        didSet {
            UserDefaults.standard.set(templateContent, forKey: "templateContent")
        }
    }
    
    private init() {
        self.useDarkMode = UserDefaults.standard.bool(forKey: "useDarkMode")
        self.titleFontSize = UserDefaults.standard.double(forKey: "titleFontSize")
        self.contentFontSize = UserDefaults.standard.double(forKey: "contentFontSize")
        self.templateTitle = UserDefaults.standard.string(forKey: "templateTitle") ?? "我的記事模板"
        self.templateContent = UserDefaults.standard.string(forKey: "templateContent") ?? ""
        
        // 設置默認值
        if self.titleFontSize == 0 {
            self.titleFontSize = 22
        }
        if self.contentFontSize == 0 {
            self.contentFontSize = 16
        }
    }
} 