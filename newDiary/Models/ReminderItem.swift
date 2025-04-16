import Foundation
import SwiftData

@Model
public final class ReminderItem: Identifiable {
    @Attribute(.unique) public var id: String
    public var title: String
    public var date: Date
    public var isCompleted: Bool
    public var createdAt: Date
    
    public init(id: String = UUID().uuidString, title: String = "", date: Date = Date(), isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.date = date
        self.isCompleted = isCompleted
        self.createdAt = Date()
    }
} 