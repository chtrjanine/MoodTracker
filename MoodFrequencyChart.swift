// File: MoodFrequencyChart.swift

import SwiftUI

// Mood frequency bar chart
struct MoodFrequencyChart: View {
    let entries: [MoodEntry]
    @Environment(\.colorScheme) var colorScheme
    
    private var chartBackground: Color {
        colorScheme == .dark ? Color(.systemGray5).opacity(0.8) : Color(.systemGray6).opacity(0.9)
    }
    
    private var moodCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for entry in entries {
            // Force all keys to lowercase to merge "happy" and "Happy"
            counts[entry.mainMood.lowercased(), default: 0] += 1
        }
        return counts
    }
    
    private var maxCount: Int {
        moodCounts.values.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            // The parent `AnalyticsView` now provides the padding and background
            Text("Mood Frequency")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom)
            
            if entries.isEmpty {
                Text("No data for frequency analysis")
                    .foregroundColor(.secondary)
                    .italic()
                    // Force the text to occupy a minimum height and full width
                    // This stops the card from collapsing and fixes alignment.
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
            } else {
                VStack(spacing: 8) {
                    ForEach(moodCounts.sorted(by: { $0.value > $1.value }), id: \.key) { mood, count in
                        HStack {
                            Text(mood.capitalized) // Display with capital letter
                                .font(.caption)
                                .foregroundColor(.primary)
                                .frame(width: 60, alignment: .leading)
                            
                            GeometryReader { geometry in
                                HStack {
                                    Rectangle()
                                        // Use the correct moodColor from Color+Extensions
                                        .fill(Color.moodColor(for: mood))
                                        .frame(width: CGFloat(count) / CGFloat(maxCount) * geometry.size.width)
                                        .animation(.easeInOut, value: count)
                                    Spacer()
                                }
                            }
                            .frame(height: 20)
                            
                            Text("\(count)")
                                .font(.caption)
                                .foregroundColor(.primary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
        // .padding(), .background(), and .cornerRadius() are removed
        // The parent `AnalyticsView` now handles the card styling.
    }
}
