// File: CalendarDayView.swift

import SwiftUI
import Foundation

// Individual calendar day view
struct CalendarDayView: View {
    let date: Date
    let moods: [String]
    let isCurrentMonth: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        ZStack {
            // Background with multiple mood colors
            if moods.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(height: 40)
            } else if moods.count == 1 {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.moodColor(for: moods[0]))
                    .frame(height: 40)
            } else {
                // Multiple moods - create segments
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(Array(moods.enumerated()), id: \.offset) { index, mood in
                            Rectangle()
                                .fill(Color.moodColor(for: mood))
                                .frame(width: geometry.size.width / CGFloat(moods.count))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(height: 40)
            }
            
            // Border
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
                .frame(height: 40)
            
            // Day number
            Text(dayNumber)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textColor)
                .opacity(isCurrentMonth ? 1.0 : 0.3)
        }
    }
    
    private var textColor: Color {
        guard !moods.isEmpty else {
            return .primary
        }
        
        // This list is based on our new Color+Extensions
        // Red, Blue, Purple, Orange are dark colors
        let darkMoods = ["angry", "sad", "disgust", "fear"]
        
        // Check if the day's moods (lowercased) contain any dark moods
        let hasDarkMood = moods.contains { darkMoods.contains($0.lowercased()) }
        
        if hasDarkMood {
            // Use white text on dark backgrounds
            return .white
        } else {
            // Use primary text color on light backgrounds (Yellow, Cyan, Gray)
            return .primary
        }
    }
}
