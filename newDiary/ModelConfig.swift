import Foundation
import SwiftData

enum ModelConfig {
    static var schema: Schema {
        Schema([
            DiaryEntry.self,
            CategoryEntry.self,
            WeatherRecord.self,
            ReminderItem.self
        ])
    }
    
    static var configurations: ModelConfiguration {
        ModelConfiguration(isStoredInMemoryOnly: false)
    }
    
    static var modelContainer: ModelContainer? {
        do {
            return try ModelContainer(for: schema, configurations: configurations)
        } catch {
            print("Error creating ModelContainer: \(error)")
            return nil
        }
    }
} 
