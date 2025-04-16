import Foundation
import SwiftData

// 修改为符合SchemaMigrationPlan协议的结构体
struct AppSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
        ]
    }
}

// 修改为符合VersionedSchema协议的结构体
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [
            DiaryEntry.self,
            CategoryEntry.self,
            WeatherRecord.self,
            ReminderItem.self
        ]
    }
}

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [
            DiaryEntry.self,
            CategoryEntry.self,
            WeatherRecord.self,
            ReminderItem.self
        ]
    }
} 
