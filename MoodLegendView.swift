// File: MoodLegendView.swift

import SwiftUI

// Mood legend component
struct MoodLegendView: View {
    @Environment(\.colorScheme) var colorScheme
    
    // Use the 7 standard (lowercase) moods
    let moods = [
        "happy", "sad", "angry", "neutral", "surprise", "disgust", "fear"
    ]
    
    private var legendBackground: Color {
        colorScheme == .dark ? Color(.systemGray5).opacity(0.8) : Color(.systemGray6).opacity(0.9)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Mood Colors") // Translated to English
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom, 8)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                
                ForEach(moods, id: \.self) { mood in
                    HStack {
                        Circle()
                            // Gets color from our new Color+Extensions
                            .fill(Color.moodColor(for: mood))
                            .frame(width: 12, height: 12)
                        Text(mood.capitalized) // Display with capital letter
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(legendBackground)
        .cornerRadius(12)
    }
}
