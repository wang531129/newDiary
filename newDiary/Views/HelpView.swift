import SwiftUI

/// 使用說明視圖
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("titleFontSize") private var titleFontSize: Double = 22
    @AppStorage("contentFontSize") private var contentFontSize: Double = 16
    
    // 獲取當前版本號
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "版本 \(version) (\(build))"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // 應用介紹
                    GroupBox {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: titleFontSize))
                                    .foregroundColor(.blue)
                                Text("關於我的日記簿")
                                    .font(.system(size: titleFontSize))
                                    .fontWeight(.bold)
                            }
                            
                            Text("我的日記簿是一款功能豐富的日記管理應用程式，專為中文使用者設計。它整合了天氣記錄、多種分類記錄和備份還原功能，幫助您全面記錄和管理生活的方方面面。")
                                .font(.system(size: contentFontSize))
                                .foregroundColor(.secondary)
                            
                            Text(appVersion)
                                .font(.system(size: contentFontSize - 2))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // 基本操作
                    GroupBox {
                        VStack(alignment: .leading, spacing: 15) {
                            SectionTitle(title: "基本操作", icon: "gear")
                            
                            HelpItem(
                                icon: "person.circle",
                                title: "個人化設置",
                                description: "在偏好設置中可以設置主人翁姓名，設置後應用程式標題會顯示為「[您的姓名]的日記」。"
                            )
                            
                            HelpItem(
                                icon: "calendar",
                                title: "日期導航",
                                description: "使用頂部日曆按鈕可以快速選擇並跳轉到指定日期的日記。也可以點擊日期區域直接前往今日日記。"
                            )
                            
                            HelpItem(
                                icon: "plus.circle.fill",
                                title: "創建日記",
                                description: "系統會自動在當前日期創建日記。若當日無日記，日期下方會出現「新增」按鈕，點擊即可創建。工具欄的「-」按鈕可用於刪除當日日記。"
                            )
                            
                            HelpItem(
                                icon: "magnifyingglass",
                                title: "搜尋功能",
                                description: "點擊工具欄的搜尋按鈕，可以在所有日記內容中進行全文搜尋，包括各類記錄的名稱、備註等。"
                            )
                            
                            HelpItem(
                                icon: "sun.max.fill",
                                title: "天氣切換",
                                description: "系統會自動獲取您當前位置的天氣資訊和地點。您也可以點擊天氣圖標手動切換當天天氣，支持多種天氣類型，如晴天、多雲、雨天等。自動天氣功能需要允許應用程式存取位置資訊。"
                            )
                            
                            HelpItem(
                                icon: "hand.point.up.fill",
                                title: "互動提示",
                                description: "在可點擊的按鈕和區域上，滑鼠指針會變成手型，方便識別可互動的元素。工具列的所有圖示在滑鼠停留時都會顯示功能提示說明。"
                            )
                            
                            HelpItem(
                                icon: "questionmark.circle",
                                title: "工具列圖示",
                                description: "工具列包含以下功能按鈕：\n· 提醒事項：顯示未完成的提醒數量\n· 搜尋：搜尋日記內容\n· 日曆：選擇日期\n· 設定：調整應用程式設定\n· 說明：開啟使用說明\n· 刪除：刪除當日日記"
                            )
                            
                            HelpItem(
                                icon: "keyboard",
                                title: "快捷鍵",
                                description: "⌘ + T：切換深淺色主題\n⌘ + F：搜索日記內容\n⌘ + N：創建新日記\n⌘ + ,：開啟偏好設置\n⌘ + ?：開啟幫助文檔"
                            )
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // 記錄功能
                    GroupBox {
                        VStack(alignment: .leading, spacing: 15) {
                            SectionTitle(title: "記錄功能", icon: "list.bullet")
                            
                            HelpItem(
                                icon: "dollarsign.circle.fill",
                                title: "支出記錄",
                                description: "記錄每日花費和消費類別，並自動計算每月總支出，追蹤個人財務狀況。支援多種消費類型分類。"
                            )
                            
                            HelpItem(
                                icon: "figure.run",
                                title: "運動記錄",
                                description: "記錄運動類型和時長，系統會自動計算總運動時間，幫助您達成健身目標。可設置每日運動目標。"
                            )
                            
                            HelpItem(
                                icon: "bed.double.fill",
                                title: "睡眠記錄",
                                description: "記錄睡眠時間和品質，關注睡眠健康。可設置每日睡眠目標，檢視睡眠模式，追蹤睡眠趨勢。"
                            )
                            
                            HelpItem(
                                icon: "briefcase.fill",
                                title: "工作記錄",
                                description: "追蹤工作項目和時間投入，瞭解工作效率和時間分配。支援項目分類和時間統計。"
                            )
                            
                            HelpItem(
                                icon: "person.2.fill",
                                title: "關係記錄",
                                description: "記錄社交互動和人際交往的時間投入，維護重要的人際關係。可追蹤互動頻率和質量。"
                            )
                            
                            HelpItem(
                                icon: "book.fill",
                                title: "學習記錄",
                                description: "追蹤學習進度和時間投入，持續自我提升和知識積累。支援學習目標設定和進度追蹤。"
                            )
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // 資料管理
                    GroupBox {
                        VStack(alignment: .leading, spacing: 15) {
                            SectionTitle(title: "資料管理", icon: "folder")
                            
                            HelpItem(
                                icon: "square.and.arrow.up",
                                title: "匯出備份",
                                description: "將日記資料匯出為JSON格式，支援選擇特定日期範圍，可保存至指定位置。建議定期備份以確保資料安全。"
                            )
                            
                            HelpItem(
                                icon: "square.and.arrow.down",
                                title: "匯入還原",
                                description: "從先前的備份檔案還原日記資料，支援智能合併，避免資料重複。系統會自動處理重複日期的資料。"
                            )
                            
                            HelpItem(
                                icon: "lock.fill",
                                title: "資料安全",
                                description: "所有資料均儲存在本地裝置，確保您的隱私安全。位置信息僅用於獲取天氣，不會上傳至第三方。"
                            )
                            
                            HelpWarning(
                                message: "請定期備份您的日記資料，以防資料丟失。建議將備份檔案保存在多個安全位置。"
                            )
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // 提醒功能
                    GroupBox {
                        VStack(alignment: .leading, spacing: 15) {
                            SectionTitle(title: "提醒功能", icon: "bell.fill")
                            
                            HelpItem(
                                icon: "bell.badge",
                                title: "設置提醒",
                                description: "在日記中可以添加提醒事項，包含日期、時間和內容。支援重複提醒和優先級設置。"
                            )
                            
                            HelpItem(
                                icon: "checkmark.circle",
                                title: "完成提醒",
                                description: "點擊提醒項目上的完成按鈕，或使用右鍵選單可將提醒標記為已完成。支援批量操作。"
                            )
                            
                            HelpItem(
                                icon: "bell.slash",
                                title: "提醒管理",
                                description: "在主界面可以查看所有未完成的提醒，支援按日期排序和分類查看。提供快速完成和刪除操作。"
                            )
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // 聯絡資訊
                    GroupBox {
                        VStack(alignment: .leading, spacing: 15) {
                            SectionTitle(title: "問題反饋", icon: "envelope.fill")
                            
                            Text("如有問題或建議，請聯繫我們：")
                                .font(.system(size: contentFontSize))
                            
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundColor(.blue)
                                Text("wanpp.d@gmail.com")
                                    .font(.system(size: contentFontSize))
                            }
                            
                            Text("版本：\(appVersion)")
                                .font(.system(size: contentFontSize - 2))
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                .padding(.vertical)
            }
            .navigationTitle("使用說明")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 幫助項目組件
struct HelpItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 章節標題
struct SectionTitle: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding(.bottom, 5)
    }
}

/// 警告提示
struct HelpWarning: View {
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundColor(.orange)
                .frame(width: 24, height: 24)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
} 