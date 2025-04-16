import Foundation
import SwiftUI
import SwiftData
import AppKit

/// 用於備份的數據結構
struct DiaryBackup: Codable {
    var entries: [DiaryBackupEntry]
    
    struct DiaryBackupEntry: Codable {
        var id: UUID
        var date: Date
        var weatherRaw: String
        var thoughts: String
        var temperature: String
        var weatherRecords: [WeatherRecordBackupEntry]
        var expenses: [CategoryBackupEntry]
        var exercises: [CategoryBackupEntry]
        var sleeps: [CategoryBackupEntry]
        var works: [CategoryBackupEntry]
        var relationships: [CategoryBackupEntry]
        var studies: [CategoryBackupEntry]
    }
    
    struct WeatherRecordBackupEntry: Codable {
        var time: Date
        var weatherRaw: String
        var temperature: String
        var location: String?
    }
    
    struct CategoryBackupEntry: Codable {
        var id: UUID
        var typeRaw: String
        var name: String
        var category: String
        var number: Double
        var notes: String
    }
}

// 備份管理器類，處理日記應用程序的備份和恢復功能
class BackupManager {
    static let shared = BackupManager()
    
    // 保存備份到指定目錄 - 使用更簡單直接的方法
    func saveBackupToCustomPath(backup: DiaryBackup, startDate: Date, endDate: Date) -> Result<URL, Error> {
        do {
            // 創建編碼器並準備數據
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(backup)
            
            // 創建文件名
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            let fileName = "diary_backup_\(dateFormatter.string(from: startDate))_to_\(dateFormatter.string(from: endDate)).json"
            
            // 先保存到臨時目錄
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(fileName)
            try data.write(to: tempURL)
            
            // 創建儲存面板，使用AppKit原生API
            let result = Result<URL, Error>.failure(BackupError.userCancelled)
            
            // 確保在主線程上顯示對話框
            DispatchQueue.main.async {
                let savePanel = NSSavePanel()
                savePanel.canCreateDirectories = true
                savePanel.showsTagField = false
                savePanel.isExtensionHidden = false
                savePanel.title = "選擇備份保存位置"
                savePanel.nameFieldStringValue = fileName
                savePanel.allowedFileTypes = ["json"]
                
                // 顯示面板
                if savePanel.runModal() == .OK, let url = savePanel.url {
                    do {
                        try FileManager.default.copyItem(at: tempURL, to: url)
                        // 保存成功後觸發通知
                        NotificationCenter.default.post(
                            name: Notification.Name("ExportCompleted"),
                            object: nil,
                            userInfo: ["url": url, "success": true]
                        )
                    } catch {
                        print("複製檔案失敗: \(error)")
                        // 觸發失敗通知
                        NotificationCenter.default.post(
                            name: Notification.Name("ExportCompleted"),
                            object: nil,
                            userInfo: ["error": error, "success": false]
                        )
                    }
                } else {
                    // 用戶取消選擇，觸發取消通知
                    NotificationCenter.default.post(
                        name: Notification.Name("ExportCompleted"),
                        object: nil,
                        userInfo: ["cancelled": true, "success": false]
                    )
                }
                
                // 清理臨時文件
                try? FileManager.default.removeItem(at: tempURL)
            }
            
            // 這裡總是返回取消結果，實際結果會通過通知處理
            return result
        } catch {
            print("準備備份數據時出錯: \(error)")
            return .failure(error)
        }
    }
    
    // 創建安全書簽，允許應用在未來訪問用戶選擇的位置
    private func createSecurityBookmarkIfNeeded(for url: URL) {
        do {
            // 獲取包含目錄的URL
            let directoryURL = url.deletingLastPathComponent()
            
            // 嘗試創建安全書簽
            let bookmarkData = try directoryURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            // 保存書簽數據到用戶默認設置
            UserDefaults.standard.set(bookmarkData, forKey: "SecurityBookmark-\(directoryURL.path)")
            
            print("已為目錄創建安全書簽: \(directoryURL.path)")
        } catch {
            print("創建安全書簽失敗: \(error)")
        }
    }
    
    // 從書簽訪問URL
    func accessURLFromBookmark(_ url: URL) -> Bool {
        let directoryURL = url.deletingLastPathComponent()
        let bookmarkKey = "SecurityBookmark-\(directoryURL.path)"
        
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            print("未找到URL的安全書簽: \(url.path)")
            return false
        }
        
        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                print("書簽已過期，需要更新")
                return false
            }
            
            // 開始訪問安全作用域資源
            if resolvedURL.startAccessingSecurityScopedResource() {
                print("成功開始訪問安全作用域資源: \(resolvedURL.path)")
                // 注意：使用完畢後應調用 stopAccessingSecurityScopedResource()
                return true
            } else {
                print("無法訪問安全作用域資源: \(resolvedURL.path)")
                return false
            }
        } catch {
            print("解析書簽時出錯: \(error)")
            return false
        }
    }
    
    // 停止訪問安全作用域資源
    func stopAccessingURL(_ url: URL) {
        let directoryURL = url.deletingLastPathComponent()
        directoryURL.stopAccessingSecurityScopedResource()
        print("已停止訪問安全作用域資源: \(directoryURL.path)")
    }
    
    // 保存備份到文檔目錄
    func saveBackup(backup: DiaryBackup, startDate: Date, endDate: Date) -> Result<URL, Error> {
        do {
            // 創建編碼器
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(backup)
            
            // 創建文件名
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            let fileName = "diary_backup_\(dateFormatter.string(from: startDate))_to_\(dateFormatter.string(from: endDate)).json"
            
            // 獲取文檔目錄
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            
            print("正在保存備份到文檔目錄: \(documentsDirectory.path)")
            
            // 嘗試創建備份目錄
            let backupsDirectory = documentsDirectory.appendingPathComponent("DiaryBackups", isDirectory: true)
            
            // 檢查備份目錄是否存在，如果不存在則創建
            var isDirectory: ObjCBool = false
            let backupDirExists = fileManager.fileExists(atPath: backupsDirectory.path, isDirectory: &isDirectory)
            
            if !backupDirExists || !isDirectory.boolValue {
                do {
                    try fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true, attributes: nil)
                    print("成功創建備份目錄: \(backupsDirectory.path)")
                } catch {
                    print("創建備份目錄失敗: \(error)")
                    // 如果無法創建備份目錄，直接使用文檔目錄
                    let fileURL = documentsDirectory.appendingPathComponent(fileName)
                    print("改為直接保存到文檔目錄: \(fileURL.path)")
                    try data.write(to: fileURL)
                    print("備份已保存到: \(fileURL.path)")
                    return Result<URL, Error>.success(fileURL)
                }
            }
            
            // 創建文件URL
            let fileURL = backupsDirectory.appendingPathComponent(fileName)
            
            // 寫入數據
            try data.write(to: fileURL)
            
            print("備份已保存到: \(fileURL.path)")
            return Result<URL, Error>.success(fileURL)
        } catch {
            print("保存備份失敗: \(error)")
            return Result<URL, Error>.failure(error)
        }
    }
    
    // 從指定URL加載備份
    func loadBackup(from url: URL) -> Result<DiaryBackup, Error> {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(DiaryBackup.self, from: data)
            return Result<DiaryBackup, Error>.success(backup)
        } catch {
            return Result<DiaryBackup, Error>.failure(error)
        }
    }
    
    // 獲取備份目錄中的所有備份文件
    func getBackupFiles() -> [URL] {
        let fileManager = FileManager.default
        var backupFiles: [URL] = []
        
        // 只使用当前应用容器的Documents目录
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let backupsDirectory = documentsDirectory.appendingPathComponent("DiaryBackups", isDirectory: true)
        
        print("當前應用文檔目錄: \(documentsDirectory.path)")
        print("備份目錄: \(backupsDirectory.path)")
        
        // 確保備份目錄存在
        if !fileManager.fileExists(atPath: backupsDirectory.path) {
            do {
                try fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true, attributes: nil)
                print("已創建備份目錄: \(backupsDirectory.path)")
            } catch {
                print("創建備份目錄失敗: \(error)")
            }
        }
        
        // 從當前應用的備份目錄查找備份
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: nil)
            let currentFiles = fileURLs.filter { $0.lastPathComponent.starts(with: "diary_backup_") && $0.pathExtension == "json" }
            backupFiles.append(contentsOf: currentFiles)
            
            print("在備份目錄中找到 \(currentFiles.count) 個備份文件")
            for file in currentFiles {
                print("  - \(file.lastPathComponent)")
            }
        } catch {
            print("讀取備份目錄失敗: \(error)")
        }
        
        // 檢查Documents目錄中的備份文件
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            let currentFiles = fileURLs.filter { $0.lastPathComponent.starts(with: "diary_backup_") && $0.pathExtension == "json" }
            
            print("在Documents目錄中找到 \(currentFiles.count) 個備份文件")
            for file in currentFiles {
                print("  - \(file.lastPathComponent)")
                
                // 移動到備份目錄
                let destURL = backupsDirectory.appendingPathComponent(file.lastPathComponent)
                if !fileManager.fileExists(atPath: destURL.path) {
                    do {
                        try fileManager.moveItem(at: file, to: destURL)
                        print("已移動備份文件到備份目錄")
                        backupFiles.append(destURL)
                    } catch {
                        print("移動備份文件失敗: \(error)")
                        backupFiles.append(file)
                    }
                } else {
                    backupFiles.append(file)
                }
            }
        } catch {
            print("讀取Documents目錄失敗: \(error)")
        }
        
        // 檢查真正的系統下載目錄
        do {
            // 正確獲取用戶下載目錄
            let userHomeDirectory = fileManager.homeDirectoryForCurrentUser
            let downloadsDirectoryURL = userHomeDirectory.appendingPathComponent("Downloads", isDirectory: true)
            
            print("嘗試訪問系統下載目錄: \(downloadsDirectoryURL.path)")
            
            let fileURLs = try fileManager.contentsOfDirectory(at: downloadsDirectoryURL, includingPropertiesForKeys: nil)
            let currentFiles = fileURLs.filter { $0.lastPathComponent.starts(with: "diary_backup_") && $0.pathExtension == "json" }
            
            print("在系統下載目錄中找到 \(currentFiles.count) 個備份文件")
            for file in currentFiles {
                print("  - \(file.lastPathComponent)")
                
                // 嘗試複製到備份目錄（而不是移動，避免刪除用戶的文件）
                let destURL = backupsDirectory.appendingPathComponent(file.lastPathComponent)
                if !fileManager.fileExists(atPath: destURL.path) {
                    do {
                        try fileManager.copyItem(at: file, to: destURL)
                        print("已複製備份文件到備份目錄")
                        backupFiles.append(destURL)
                    } catch {
                        print("複製備份文件失敗: \(error)")
                        backupFiles.append(file)
                    }
                } else {
                    backupFiles.append(file)
                }
            }
        } catch {
            print("讀取系統下載目錄失敗: \(error)")
        }
        
        // 檢查真正的系統桌面目錄
        do {
            // 正確獲取用戶桌面目錄
            let userHomeDirectory = fileManager.homeDirectoryForCurrentUser
            let desktopDirectoryURL = userHomeDirectory.appendingPathComponent("Desktop", isDirectory: true)
            
            print("嘗試訪問系統桌面目錄: \(desktopDirectoryURL.path)")
            
            let fileURLs = try fileManager.contentsOfDirectory(at: desktopDirectoryURL, includingPropertiesForKeys: nil)
            let currentFiles = fileURLs.filter { $0.lastPathComponent.starts(with: "diary_backup_") && $0.pathExtension == "json" }
            
            print("在系統桌面目錄中找到 \(currentFiles.count) 個備份文件")
            for file in currentFiles {
                print("  - \(file.lastPathComponent)")
                
                // 嘗試複製到備份目錄（而不是移動，避免刪除用戶的文件）
                let destURL = backupsDirectory.appendingPathComponent(file.lastPathComponent)
                if !fileManager.fileExists(atPath: destURL.path) {
                    do {
                        try fileManager.copyItem(at: file, to: destURL)
                        print("已複製備份文件到備份目錄")
                        backupFiles.append(destURL)
                    } catch {
                        print("複製備份文件失敗: \(error)")
                        backupFiles.append(file)
                    }
                } else {
                    backupFiles.append(file)
                }
            }
        } catch {
            print("讀取系統桌面目錄失敗: \(error)")
        }
        
        // 按照最後修改時間排序，最新的在前面
        backupFiles.sort { (url1, url2) -> Bool in
            do {
                let attrs1 = try fileManager.attributesOfItem(atPath: url1.path)
                let attrs2 = try fileManager.attributesOfItem(atPath: url2.path)
                let date1 = attrs1[.modificationDate] as? Date ?? Date.distantPast
                let date2 = attrs2[.modificationDate] as? Date ?? Date.distantPast
                return date1 > date2
            } catch {
                return false
            }
        }
        
        print("總共找到 \(backupFiles.count) 個備份文件")
        return backupFiles
    }
    
    // 將備份文件導出到下載目錄
    func exportBackupToDownloads(url: URL) -> URL? {
        let fileManager = FileManager.default
        
        // 正確獲取用戶下載目錄
        let userHomeDirectory = fileManager.homeDirectoryForCurrentUser
        let downloadsDirectoryURL = userHomeDirectory.appendingPathComponent("Downloads", isDirectory: true)
        
        print("準備將備份文件導出到系統下載目錄: \(downloadsDirectoryURL.path)")
        
        let destURL = downloadsDirectoryURL.appendingPathComponent(url.lastPathComponent)
        
        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
                print("已刪除下載目錄中的同名文件")
            }
            try fileManager.copyItem(at: url, to: destURL)
            print("已將備份導出到下載目錄: \(destURL.path)")
            return destURL
        } catch {
            print("導出備份失敗: \(error)")
            return nil
        }
    }
    
    // 錯誤類型
    enum BackupError: Error, LocalizedError {
        case directoryAccessError
        case writeError
        case readError
        case userCancelled
        
        var errorDescription: String? {
            switch self {
            case .directoryAccessError:
                return "無法訪問目錄"
            case .writeError:
                return "寫入備份文件失敗"
            case .readError:
                return "讀取備份文件失敗"
            case .userCancelled:
                return "用戶取消了操作"
            }
        }
    }
}
