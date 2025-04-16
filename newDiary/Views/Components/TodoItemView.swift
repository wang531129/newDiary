import SwiftUI

struct TodoItemView: View {
    @Binding var text: String
    let onToggle: () -> Void
    
    private var isCompleted: Bool {
        text.hasPrefix("✅")
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Text(isCompleted ? "✅" : "🔳")
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(text.replacingOccurrences(of: "^[✅🔳]\\s*", with: "", options: .regularExpression))
                .foregroundColor(.white)
                .font(.system(size: 14))
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    VStack {
        TodoItemView(text: .constant("🔳 未完成的任务"), onToggle: {})
        TodoItemView(text: .constant("✅ 已完成的任务"), onToggle: {})
    }
    .padding()
    .background(Color.black)
} 