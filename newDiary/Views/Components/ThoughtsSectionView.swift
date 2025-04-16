import SwiftUI

// MARK: - Thoughts Section View
struct ThoughtsSectionView: View {
    @Binding var thoughts: String
    let titleFontSize: Double
    let titleFontColor: String
    let saveContext: () -> Void
    let diary: DiaryEntry
    
    // 動畫狀態
    @State private var isFocused: Bool = false
    @State private var showSavedIndicator: Bool = false
    @State private var appearScale: CGFloat = 0.98
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("記事")
                    .font(.system(size: titleFontSize))
                    .foregroundColor(Color.fromString(titleFontColor))
                
                Spacer()
                
                if showSavedIndicator {
                    Label("已保存", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.footnote)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            HStack(spacing: 8) {
                TextEditor(text: $thoughts)
                    .font(.body)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onTapGesture {
                        isFocused = true
                    }
                    .onChange(of: thoughts) { oldValue, newValue in
                        diary.thoughts = newValue
                        saveContext()
                        
                        withAnimation {
                            showSavedIndicator = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showSavedIndicator = false
                            }
                        }
                    }
                
                VStack(spacing: 8) {
                    Button(action: {
                        toggleTodoAtCurrentLine()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "checklist.checked")
                                .font(.system(size: 20))
                            Text("待辦")
                                .font(.system(size: 12))
                        }
                        .frame(width: 44, height: 44)
                        .foregroundColor(.white)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("點擊添加待辦標記")
                }
            }
            .frame(minHeight: 100)
        }
    }
    
    // 切换当前行的待办标记
    private func toggleTodoAtCurrentLine() {
        // 如果文本为空，直接添加待办标记
        if thoughts.isEmpty {
            thoughts = "🔳 "
            diary.thoughts = thoughts
            saveContext()
            return
        }
        
        // 获取当前文本的所有行
        var lines = thoughts.components(separatedBy: .newlines)
        
        // 如果最后一行为空，添加新的待办事项
        if lines.last?.isEmpty ?? true {
            lines[lines.count - 1] = "🔳 "
        } else {
            // 在最后添加新行
            lines.append("🔳 ")
        }
        
        // 更新文本
        thoughts = lines.joined(separator: "\n")
        diary.thoughts = thoughts
        saveContext()
        
        // 显示保存指示器
        withAnimation {
            showSavedIndicator = true
        }
        
        // 延迟隐藏保存指示器
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSavedIndicator = false
            }
        }
    }
    
    // 获取光标所在行
    private func getCurrentLine() -> (Int, String)? {
        let lines = thoughts.components(separatedBy: .newlines)
        
        // 如果文本为空，返回第一行
        if thoughts.isEmpty {
            return (0, "")
        }
        
        // 默认返回最后一行
        return (lines.count - 1, lines.last ?? "")
    }
} 
