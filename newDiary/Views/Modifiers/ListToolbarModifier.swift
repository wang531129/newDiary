import SwiftUI
// import only needed for SwiftUI components, no other dependencies

// MARK: - Sheet Types
enum ToolbarSheetType: Identifiable {
    case newDiary
    case preferences
    case dateRange
    case help
    case backupSelection
    
    var id: Int {
        switch self {
        case .newDiary: return 1
        case .preferences: return 2
        case .dateRange: return 3
        case .help: return 4
        case .backupSelection: return 5
        }
    }
}

// MARK: - Modifiers
struct ListToolbarModifier: ViewModifier {
    let toggleSearchField: () -> Void
    let showSearchField: Bool
    let switchToToday: () -> Void
    @Binding var isExporting: Bool
    @Binding var activeSheet: ToolbarSheetType?
    
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: toggleSearchField) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(showSearchField ? .blue : .primary)
                }
                .keyboardShortcut("f", modifiers: .command)
                .help("搜尋日記內容")
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: switchToToday) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.primary)
                }
                .keyboardShortcut("t", modifiers: .command)
                .help("前往今日日記")
            }
        }
    }
} 