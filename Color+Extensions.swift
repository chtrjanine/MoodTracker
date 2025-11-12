// File: Color+Extensions.swift

import SwiftUI

// This is the single source of truth for mood colors in the app.
extension Color {
    
    /// Returns the color for one of the 7 standard moods.
    static func moodColor(for mood: String) -> Color {
        // Use .lowercased() to ensure "Happy" and "happy" both match
        switch mood.lowercased() {
        case "happy":
            return .green // <-- CHANGED FROM .yellow TO .green
        case "sad":
            return .blue
        case "angry":
            return .red
        case "neutral":
            return .gray
        case "surprise":
            return .cyan
        case "disgust":
            return .purple
        case "fear":
            return .orange
        default:
            return .gray.opacity(0.5) // Fallback
        }
    }
    
    /// Provides the same color for charts.
    static func chartMoodColor(for mood: String) -> Color {
        return moodColor(for: mood)
    }
}
