//
//  newDiaryApp.swift
//  newDiary
//
//  Created by WangPuma on 2025/3/18.
//

import SwiftUI
import SwiftData
import LocalAuthentication
import AppKit

// 添加應用程序代理以處理窗口關閉事件
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true // 讓應用程序在最後一個窗口關閉後終止
    }
}

@main
struct newDiaryApp: App {
    // MARK: - 屬性
    @AppStorage("isDarkMode") private var isDarkMode = true
    @State private var showMainView = true
    @State private var showingResetConfirmation = false
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let container: ModelContainer
    
    init() {
        print("開始初始化 ModelContainer")
        
        do {
            let schema = Schema([
                DiaryEntry.self,
                CategoryEntry.self,
                WeatherRecord.self,
                ReminderItem.self,
                Reminder.self
            ])
            print("Schema 創建成功")
            
            let config = ModelConfiguration(schema: schema)
            print("ModelConfiguration 創建成功")
            
            do {
                print("嘗試創建 ModelContainer")
                container = try ModelContainer(for: schema, configurations: config)
                print("ModelContainer 創建成功")
            } catch {
                print("創建 ModelContainer 失敗: \(error)")
                print("嘗試使用基本配置")
                container = try ModelContainer(for: schema)
            }
        } catch {
            print("初始化失敗: \(error)")
            fatalError("無法初始化 ModelContainer: \(error)")
        }
        
        // 防止README.md文件重複複製
        UserDefaults.standard.register(defaults: ["HasCopiedReadme": false])
    }
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .modelContainer(container)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showingResetConfirmation = true }) {
                            Label("重置數據庫", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                        }
                    }
                }
                .alert("重置數據庫", isPresented: $showingResetConfirmation) {
                    Button("取消", role: .cancel) {}
                    Button("確認重置", role: .destructive) {
                        resetDatabase()
                    }
                } message: {
                    Text("此操作將刪除所有數據並重建數據庫。此操作不可逆，請確認是否繼續？")
                }
                .onAppear {
                    // 確保只有一次複製README.md資源文件
                    if !UserDefaults.standard.bool(forKey: "HasCopiedReadme") {
                        copyReadMeFile()
                        UserDefaults.standard.set(true, forKey: "HasCopiedReadme")
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1000, height: 800)
        .commands {
            CommandMenu("自定義") {
                Button("切換主題") {
                    isDarkMode.toggle()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                
                Divider()
                
                Button("重置數據庫") {
                    showingResetConfirmation = true
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
            }
        }
    }
    
    private func resetDatabase() {
        // 查找並刪除所有可能的數據庫文件
        let fileManager = FileManager.default
        let possibleDatabaseLocations = [
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!,
            fileManager.temporaryDirectory
        ]
        
        for baseURL in possibleDatabaseLocations {
            // 尋找可能的數據庫文件
            let potentialDBFiles = [
                "default.store",
                "newDiaryDB.sqlite",
                "DiaryStore.sqlite",
                "newDiary.sqlite"
            ]
            
            for dbName in potentialDBFiles {
                let dbURL = baseURL.appendingPathComponent(dbName)
                // 刪除主數據庫文件
                if fileManager.fileExists(atPath: dbURL.path) {
                    try? fileManager.removeItem(at: dbURL)
                    print("已刪除數據庫文件: \(dbURL.path)")
                }
                
                // 刪除關聯的輔助文件
                let shmURL = baseURL.appendingPathComponent("\(dbName)-shm")
                let walURL = baseURL.appendingPathComponent("\(dbName)-wal")
                
                if fileManager.fileExists(atPath: shmURL.path) {
                    try? fileManager.removeItem(at: shmURL)
                }
                
                if fileManager.fileExists(atPath: walURL.path) {
                    try? fileManager.removeItem(at: walURL)
                }
            }
        }
        
        // 重新啓動應用
        NSApplication.shared.terminate(nil)
    }
    
    // 複製README.md文件到應用資源目錄，只執行一次
    private func copyReadMeFile() {
        print("README.md已包含在應用資源中")
    }
}

// MARK: - 認證視圖

/// 生物識別認證視圖
struct AuthView: View {
    @Binding var isUnlocked: Bool
    @State private var errorMessage = ""
    @State private var isAuthenticating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("我的日記")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("使用生物識別解鎖")
                .font(.headline)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }
            
            Button(action: authenticate) {
                HStack {
                    Image(systemName: "faceid")
                    Text("解鎖")
                }
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(10)
            }
            .disabled(isAuthenticating)
        }
        .padding()
        .frame(width: 300, height: 300)
        .onAppear(perform: authenticate)
    }
    
    // 執行認證
    private func authenticate() {
        isAuthenticating = true
        
        // 這裡應使用實際的LocalAuthentication框架
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "使用生物識別驗證以訪問日記"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    isAuthenticating = false
                    
                    if success {
                        isUnlocked = true
                        errorMessage = ""
                    } else {
                        errorMessage = "驗證失敗: \(authenticationError?.localizedDescription ?? "未知錯誤")"
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                isAuthenticating = false
                errorMessage = "設備不支持生物識別驗證"
                
                // 開發模式: 直接解鎖
                #if DEBUG
                isUnlocked = true
                #endif
            }
        }
    }
}
