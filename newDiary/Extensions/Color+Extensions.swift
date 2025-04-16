import SwiftUI

public extension Color {
    static func fromString(_ colorName: String) -> Color {
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
    
    static func colorFromString(_ colorName: String) -> Color {
        return fromString(colorName)
    }
} 
