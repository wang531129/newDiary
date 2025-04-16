import SwiftUI

/// 偏好設置視圖
struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // 用戶名稱
    @AppStorage("userName") private var userName: String = "我的"
    
    // 字體設置
    @AppStorage("titleFontSize") private var titleFontSize: Double = 22
    @AppStorage("contentFontSize") private var contentFontSize: Double = 16
    
    // 顏色設置
    @AppStorage("titleFontColor") private var titleFontColor: String = "Green"
    @AppStorage("contentFontColor") private var contentFontColor: String = "White"
    
    // 目標設置
    @AppStorage("monthlyExpenseLimit") private var monthlyExpenseLimit: Double = 20000
    @AppStorage("dailyExerciseGoal") private var dailyExerciseGoal: Double = 60
    @AppStorage("dailySleepGoal") private var dailySleepGoal: Double = 390
    @AppStorage("dailyWorkGoal") private var dailyWorkGoal: Double = 120
    @AppStorage("dailyRelationshipGoal") private var dailyRelationshipGoal: Double = 30
    @AppStorage("dailyStudyGoal") private var dailyStudyGoal: Double = 60
    
    // 模板設置
    @AppStorage("templateTitle") private var templateTitle: String = "我的記事模板"
    @AppStorage("templateContent") private var templateContent: String = ""
    
    // 天氣設置
    @AppStorage("weatherApiKey") private var weatherApiKey: String = ""
    
    // 安全設置
    @AppStorage("useBiometricAuth") private var useBiometricAuth: Bool = false
    
    // 可用的顏色選項
    private let availableColors = ["Red", "Green", "Blue", "Orange", "Purple", "Yellow", "White", "Black"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // 主人翁設置
                VStack(alignment: .leading, spacing: 20) {
                    Text("主人翁設置")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("姓名")
                                .foregroundColor(.green)
                            TextField("請輸入您的姓名", text: $userName)
                                .textFieldStyle(.roundedBorder)
                                .customCursor(.pointingHand)
                        }
                        .padding()
                    }
                }
                
                // 字體設置
                VStack(alignment: .leading, spacing: 20) {
                    Text("字體設置")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 20) {
                            // 標題字體大小設置
                            VStack(alignment: .leading, spacing: 5) {
                                Text("標題字體大小: \(Int(titleFontSize))")
                                    .foregroundColor(Color.fromString(titleFontColor))
                                    .font(.system(size: titleFontSize))
                                
                                Slider(value: $titleFontSize, in: 14...32, step: 1)
                            }
                            
                            // 內容字體大小設置
                            VStack(alignment: .leading, spacing: 5) {
                                Text("內容字體大小: \(Int(contentFontSize))")
                                    .foregroundColor(Color.fromString(contentFontColor))
                                    .font(.system(size: contentFontSize))
                                
                                Slider(value: $contentFontSize, in: 12...28, step: 1)
                            }
                            
                            // 標題顏色選擇
                            HStack {
                                Text("標題字體顏色")
                                Spacer()
                                Menu {
                                    ForEach(availableColors, id: \.self) { color in
                                        Button(color) {
                                            titleFontColor = color
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Color.fromString(titleFontColor)
                                            .frame(width: 15, height: 15)
                                            .cornerRadius(3)
                                        Text(titleFontColor)
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                                }
                            }
                            
                            // 內容顏色選擇
                            HStack {
                                Text("內容字體顏色")
                                Spacer()
                                Menu {
                                    ForEach(availableColors, id: \.self) { color in
                                        Button(color) {
                                            contentFontColor = color
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Color.fromString(contentFontColor)
                                            .frame(width: 15, height: 15)
                                            .cornerRadius(3)
                                        Text(contentFontColor)
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // 記事模板設置
                VStack(alignment: .leading, spacing: 20) {
                    Text("記事模板設置")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("模板標題")
                                .foregroundColor(.green)
                            TextField("請輸入模板標題", text: $templateTitle)
                                .textFieldStyle(.roundedBorder)
                                .customCursor(.pointingHand)
                            
                            Text("模板內容")
                                .foregroundColor(.green)
                                .padding(.top, 8)
                            TextEditor(text: $templateContent)
                                .font(.system(size: contentFontSize))
                                .foregroundColor(Color.fromString(contentFontColor))
                                .scrollContentBackground(.hidden)
                                .frame(height: 150)
                                .padding(4)
                                .background(Color(.textBackgroundColor).opacity(0.4))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding()
                    }
                }
                
                // 目標設置
                VStack(alignment: .leading, spacing: 20) {
                    Text("目標設置")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    GroupBox {
                        VStack(spacing: 15) {
                            // 月支出上限
                            HStack {
                                Text("月支出上限")
                                    .foregroundColor(.green)
                                Spacer()
                                TextField("", value: $monthlyExpenseLimit, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            // 每日運動時間
                            HStack {
                                Text("每日運動時間")
                                    .foregroundColor(.green)
                                Spacer()
                                TextField("", value: $dailyExerciseGoal, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            // 每日睡眠時間
                            HStack {
                                Text("每日睡眠時間")
                                    .foregroundColor(.green)
                                Spacer()
                                TextField("", value: $dailySleepGoal, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            // 每日工作時間
                            HStack {
                                Text("每日工作時間")
                                    .foregroundColor(.green)
                                Spacer()
                                TextField("", value: $dailyWorkGoal, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            // 每日關係經營
                            HStack {
                                Text("每日關係經營")
                                    .foregroundColor(.green)
                                Spacer()
                                TextField("", value: $dailyRelationshipGoal, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            // 每日學習時間
                            HStack {
                                Text("每日學習時間")
                                    .foregroundColor(.green)
                                Spacer()
                                TextField("", value: $dailyStudyGoal, formatter: NumberFormatter())
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                        }
                        .padding()
                    }
                }
                
                // 天氣設置
                VStack(alignment: .leading, spacing: 20) {
                    Text("天氣設置")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("OpenWeatherMap API Key")
                                .foregroundColor(.green)
                            TextField("API Key", text: $weatherApiKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding()
                    }
                }
                
                // 安全設置
                VStack(alignment: .leading, spacing: 20) {
                    Text("安全設置")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    GroupBox {
                        Toggle("使用指紋解鎖", isOn: $useBiometricAuth)
                            .padding()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
        }
        .navigationTitle("偏好設置")
        .frame(minWidth: 500, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    dismiss()
                }
            }
        }
    }
} 