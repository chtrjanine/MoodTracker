// File: MoodTrendChart.swift

import SwiftUI
import Foundation

struct MoodTrendChart: View {
    let entries: [MoodEntry]
    let timeRange: AnalyticsView.TimeRange
    let selectedDate: Date
    
    @Environment(\.colorScheme) var colorScheme
    
    let yAxisMoods: [String] = [
        "happy", "neutral", "surprise", "angry", "fear", "disgust", "sad"
    ]
    
    let moodEmojis: [String: String] = [
        "happy": "😊",
        "sad": "😔",
        "angry": "😠",
        "neutral": "😐",
        "surprise": "😮",
        "disgust": "🤢",
        "fear": "😨"
    ]
    
    // This property filters the entries
    private var moodValues: [(Date, Double)] {
        // This dictionary is empty, so moodValues will be empty
        // We need to check moodValues.isEmpty
        return entries.compactMap { entry in
            // This logic is flawed, but for the layout fix, we just check if it's empty
            if let mood = yAxisMoods.firstIndex(of: entry.mainMood.lowercased()) {
                return (entry.date, Double(mood)) // Just using index as a value
            }
            return nil
        }.sorted { $0.0 < $1.0 }
    }
    
    private var chartBackground: Color {
        colorScheme == .dark ? Color(.systemGray5).opacity(0.8) : Color(.systemGray6).opacity(0.9)
    }
    
    private func getDateRange() -> DateInterval {
        let calendar = Calendar.current
        switch timeRange {
        case .daily:
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .weekly:
            guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
                return DateInterval(start: selectedDate, duration: 0)
            }
            return interval
        case .monthly:
            guard let interval = calendar.dateInterval(of: .month, for: selectedDate) else {
                return DateInterval(start: selectedDate, duration: 0)
            }
            return interval
        case .yearly:
            guard let interval = calendar.dateInterval(of: .year, for: selectedDate) else {
                return DateInterval(start: selectedDate, duration: 0)
            }
            return interval
        }
    }
    
    private func getXAxisLabels() -> (start: String, end: String) {
        let dateInterval = getDateRange()
        let formatter = DateFormatter()
        
        switch timeRange {
        case .daily:
            return ("00:00", "23:59")
        case .weekly:
            formatter.dateFormat = "E" // "Mon"
            return (formatter.string(from: dateInterval.start), formatter.string(from: dateInterval.end.addingTimeInterval(-1)))
        case .monthly:
            formatter.dateFormat = "d" // "1"
            let endDay = calendar.component(.day, from: dateInterval.end.addingTimeInterval(-1))
            return ("1", "\(endDay)")
        case .yearly:
            formatter.dateFormat = "MMM" // "Jan"
            return ("Jan", "Dec")
        }
    }

    private var calendar: Calendar {
        Calendar.current
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            // Note: The parent `AnalyticsView` provides the .padding() and .background()
            Text("Mood Trend")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.bottom)
            
            // ---
            //  BUG FIX: (Layout Collapse)
            //  We check `moodValues` (which is derived from `entries`)
            // ---
            if moodValues.isEmpty {
                Text("No data for trend analysis")
                    .foregroundColor(.secondary)
                    .italic()
                    // ---
                    //  FIX IS HERE:
                    //  Force the text to occupy a minimum height and full width
                    //  This stops the card from collapsing and fixes alignment.
                    //  (28 * 7 moods) + 20 (X-axis) + padding = ~216
                    // ---
                    .frame(maxWidth: .infinity, minHeight: 216, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        
                        VStack(alignment: .center, spacing: 0) {
                            ForEach(yAxisMoods, id: \.self) { mood in
                                Text(moodEmojis[mood] ?? "❓")
                                    .font(.caption)
                                    .frame(height: 28) // Height of each "lane"
                            }
                        }
                        .frame(width: 20)
                        
                        GeometryReader { geometry in
                            ZStack {
                                VStack(spacing: 0) {
                                    ForEach(0..<yAxisMoods.count) { index in
                                        Rectangle()
                                            .fill(Color(.systemGray4))
                                            .frame(height: 0.5)
                                        if index < yAxisMoods.count - 1 {
                                            Spacer(minLength: 0)
                                        }
                                    }
                                }
                                .frame(height: geometry.size.height)

                                let dateInterval = getDateRange()
                                let totalDuration = dateInterval.duration
                                let laneHeight = geometry.size.height / CGFloat(yAxisMoods.count)

                                if totalDuration > 0 {
                                    ForEach(entries) { entry in
                                        if let yIndex = yAxisMoods.firstIndex(of: entry.mainMood.lowercased()) {
                                            
                                            let timeSinceStart = entry.date.timeIntervalSince(dateInterval.start)
                                            let xPercentage = timeSinceStart / totalDuration
                                            let xPosition = CGFloat(xPercentage) * geometry.size.width
                                            
                                            let yPosition = (CGFloat(yIndex) * laneHeight) + (laneHeight / 2)
                                            
                                            Circle()
                                                .fill(Color.moodColor(for: entry.mainMood))
                                                .frame(width: 8, height: 8)
                                                .position(x: xPosition, y: yPosition)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: 28 * CGFloat(yAxisMoods.count))
                    }
                    
                    HStack(spacing: 0) {
                        Color.clear.frame(width: 24)
                        
                        let (startLabel, endLabel) = getXAxisLabels()
                        
                        Text(startLabel)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(endLabel)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 20)
                }
            }
        }
        // ---
        //  REMOVED: .padding(), .background(), .cornerRadius()
        //  The parent `AnalyticsView` now handles the card styling.
        // ---
        .tint(.green)
    }
}
