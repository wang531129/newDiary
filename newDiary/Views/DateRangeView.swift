import SwiftUI
import SwiftData
import Foundation

// 添加Color擴展，用於從字符串獲取顏色
extension Color {
    static func getFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "white": return .white
        case "black": return .black
        case "gray": return .gray
        default: return .primary
        }
    }
}

struct DateRangeView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Environment(\.dismiss) private var dismiss
    var onConfirm: () -> Void
    
    // 使用AppStorage訪問全局設定的字體大小和顏色
    @AppStorage("titleFontSize") private var titleFontSize: Double = 22
    @AppStorage("contentFontSize") private var contentFontSize: Double = 16
    @AppStorage("titleFontColor") private var titleFontColor: String = "Orange"
    @AppStorage("contentFontColor") private var contentFontColor: String = "White"
    
    var body: some View {
        VStack(spacing: 30) {
            Text("選擇日期範圍")
                .font(.system(size: CGFloat(titleFontSize) * 1.2))
                .foregroundColor(getColorFromString(titleFontColor))
                .padding(.top, 30)
            
            VStack(spacing: 20) {
                // 選擇開始日期
                Section {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("起始日期")
                            .font(.system(size: CGFloat(titleFontSize)))
                            .foregroundColor(getColorFromString(titleFontColor))
                            .padding(.horizontal)
                        
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "zh_TW"))
                            
                    }
                }
                
                // 選擇結束日期
                Section {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("結束日期")
                            .font(.system(size: CGFloat(titleFontSize)))
                            .foregroundColor(getColorFromString(titleFontColor))
                            .padding(.horizontal)
                        
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "zh_TW"))
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 顯示選擇的日期範圍
            Text("選擇範圍：\(formatDateRange(startDate, endDate))")
                .font(.system(size: contentFontSize))
                .foregroundColor(.secondary)
                .padding(.bottom, 15)
            
            // 添加提示訊息
            Text("點擊確定後將立即匯出所選日期範圍內的日記資料")
                .font(.system(size: contentFontSize))
                .foregroundColor(.secondary)
                .padding(.bottom, 15)
            
            // 按鈕區域
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Text("取消")
                        .frame(minWidth: 100)
                        .padding(.vertical, 12)
                        .foregroundColor(.red)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: {
                    onConfirm()
                    dismiss()
                }) {
                    Text("確定")
                        .frame(minWidth: 100)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }
    
    // 輔助方法來獲取顏色
    private func getColorFromString(_ colorName: String) -> Color {
        return Color.getFromString(colorName)
    }
    
    // 格式化日期範圍為中文格式
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_TW")
        
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        
        return "\(startString) 至 \(endString)"
    }
}

// 預覽
#Preview {
    DateRangeView(
        startDate: .constant(Date()),
        endDate: .constant(Date()),
        onConfirm: {}
    )
}
