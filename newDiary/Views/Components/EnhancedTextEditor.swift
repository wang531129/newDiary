import SwiftUI
import AppKit

struct EnhancedTextEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }
        
        textView.isRichText = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.delegate = context.coordinator
        
        // 设置按键事件监听器
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 36 { // Return key
                handleReturn(textView: textView)
                return nil
            }
            return event
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func handleReturn(textView: NSTextView) {
        guard let selectedRange = textView.selectedRanges.first?.rangeValue else {
            return
        }
        
        let nsString = text as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let line = nsString.substring(with: lineRange)
        
        var newText = text
        if line.hasPrefix("🔳 ") {
            // 将🔳替换为✅
            let updatedLine = "✅ " + line.dropFirst(3)
            newText = (text as NSString).replacingCharacters(in: lineRange, with: updatedLine)
        } else if line.hasPrefix("✅ ") {
            // 将✅替换为🔳
            let updatedLine = "🔳 " + line.dropFirst(3)
            newText = (text as NSString).replacingCharacters(in: lineRange, with: updatedLine)
        } else {
            // 在行首添加🔳
            let updatedLine = "🔳 " + line
            newText = (text as NSString).replacingCharacters(in: lineRange, with: updatedLine)
        }
        
        text = newText
        textView.string = newText
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EnhancedTextEditor
        
        init(_ parent: EnhancedTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
} 