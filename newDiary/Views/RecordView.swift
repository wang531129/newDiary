import SwiftUI

struct RecordView: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var textEditorHeight: CGFloat = 200
    
    var body: some View {
        VStack(spacing: 16) {
            // 上方的關閉按鈕
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .padding(.top, 16)
            }
            
            // 編輯區域
            TextEditor(text: $text)
                .font(.body)
                .padding()
                .frame(minHeight: textEditorHeight)
                .background(Color(.textBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            
            // 下方的關閉按鈕
            Button {
                dismiss()
            } label: {
                Text("關閉")
                    .frame(width: 100)
                    .padding(.vertical, 8)
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 500, height: 350)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview {
    RecordView(text: .constant("測試記事內容"))
}
