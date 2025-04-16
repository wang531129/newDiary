import SwiftUI
import SwiftData
import AppKit

/// 這個視圖是一個過渡佔位符，用於替代原始ContentView
/// 實際應用程序邏輯已移至Views/MainContentView
struct ForwardingView: View {
    // 使用綁定來允許父視圖直接控制導航狀態
    @Binding var shouldShowMainView: Bool
    
    // 初始化器，提供一個默認值以保持向後兼容性
    init(shouldShowMainView: Binding<Bool> = .constant(false)) {
        self._shouldShowMainView = shouldShowMainView
    }
    
    var body: some View {
        // 顯示一個簡單的引導頁面
        VStack(spacing: 20) {
            // ... existing code ...
        }
        .padding()
        .frame(minWidth: 800, maxWidth: 1200)
        .onAppear {
            // ... existing code ...
        }
    }
}

// 为了解决编译器的错误，我们定义一个ContentView结构体作为入口点
struct ContentView: View {
    @State private var shouldShowMainView = false
    
    var body: some View {
        ForwardingView(shouldShowMainView: $shouldShowMainView)
            .frame(minWidth: 800, maxWidth: 1200)
    }
} 