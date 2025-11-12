// File: AnalyticsView.swift

import SwiftUI
import Foundation

// Enhanced Analytics View with Calendar and Charts
struct AnalyticsView: View {
    @State private var entries: [MoodEntry] = []
    @State private var selectedView: AnalyticsViewType = .calendar
    @State private var selectedTimeRange: TimeRange = .weekly
    @State private var selectedDate = Date()
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("selectedTheme") private var selectedTheme = "Default"
    
    enum AnalyticsViewType: String, CaseIterable {
        case calendar = "Calendar"
        case chart = "Chart"
    }
    
    enum TimeRange: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        case yearly = "Yearly"
    }
    
    // Helper property to filter entries based on state
    private var filteredEntries: [MoodEntry] {
        let calendar = Calendar.current
        
        switch selectedTimeRange {
        case .daily:
            return entries.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
        case .weekly:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
                return []
            }
            return entries.filter {
                $0.date >= weekInterval.start && $0.date < weekInterval.end
            }
        case .monthly:
            return entries.filter { calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .month) }
        case .yearly:
            return entries.filter { calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .year) }
        }
    }
    
    // Adaptive background for chart containers
    private var chartBackground: Color {
        colorScheme == .dark ? Color(.systemGray5).opacity(0.8) : Color(.systemGray6).opacity(0.9)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    Picker("View Type", selection: $selectedView) {
                        ForEach(AnalyticsViewType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.top, 10)
                        
                    if entries.isEmpty {
                        // Empty state remains the same
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text("No mood data yet")
                                .font(.title2)
                                .foregroundColor(.primary)
                            Text("Start tracking your mood to see analytics")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                        Spacer()
                    } else {
                        if selectedView == .calendar {
                            MoodCalendarView(entries: entries)
                        
                        } else {
                            // --- Chart View ---
                            
                            // --- Card 1: Trend Chart (MERGED) ---
                            VStack(spacing: 16) {
                                // Controls are inside the card
                                Picker("Time Range", selection: $selectedTimeRange) {
                                    ForEach(TimeRange.allCases, id: \.self) { range in
                                        Text(range.rawValue).tag(range)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                
                                HStack {
                                    Button(action: { changeDate(-1) }) {
                                        Image(systemName: "chevron.left")
                                            .font(.title3)
                                    }
                                    Spacer()
                                    Text(dateRangeString(from: selectedDate))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.5)
                                        .padding(.horizontal, 5)
                                    Spacer()
                                    Button(action: { changeDate(1) }) {
                                        Image(systemName: "chevron.right")
                                            .font(.title3)
                                    }
                                }
                                
                                Divider()
                                
                                // The chart itself
                                MoodTrendChart(
                                    entries: filteredEntries,
                                    timeRange: selectedTimeRange,
                                    selectedDate: selectedDate
                                )
                            }
                            .padding()
                            .background(chartBackground)
                            .cornerRadius(12)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)

                            
                            // --- Card 2: Frequency Chart ---
                            MoodFrequencyChart(entries: filteredEntries)
                                .padding()
                                .background(chartBackground)
                                .cornerRadius(12)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Analytics")
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .onAppear {
                loadMoodEntries()
            }
        }
        .tint(.green)
    }
    
    // --- Helper functions ---
    
    private func changeDate(_ value: Int) {
        let calendar = Calendar.current
        let component: Calendar.Component
        
        switch selectedTimeRange {
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        case .yearly: component = .year
        }
        
        if let newDate = calendar.date(byAdding: component, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func dateRangeString(from date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        switch selectedTimeRange {
        case .daily:
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        case .weekly:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
                return ""
            }
            let startOfWeek = weekInterval.start
            let endOfWeek = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? date
            
            formatter.dateFormat = "MMM d"
            let startString = formatter.string(from: startOfWeek)
            
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "d"
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"

            let finalEndString: String
            if calendar.component(.month, from: startOfWeek) == calendar.component(.month, from: endOfWeek) {
                finalEndString = "\(dayFormatter.string(from: endOfWeek)), \(yearFormatter.string(from: endOfWeek))"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
                finalEndString = formatter.string(from: endOfWeek)
            }

            return "\(startString) - \(finalEndString)"
            
        case .monthly:
            // --- FIX APPLIED HERE ---
            formatter.dateFormat = "MMMM yyyy" // Corrected from "MMMM yyyY" or similar
            return formatter.string(from: date)
            // --- END FIX ---
        case .yearly:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: date)
        }
    }
    
    func loadMoodEntries() {
            guard let userID = authViewModel.userSession?.uid else {
                print("DEBUG: Cannot load analytics, user not logged in.")
                return
            }
            
            Task {
                do {
                    self.entries = try await DatabaseService.shared.fetchMoodEntries(forUserID: userID)
                } catch {
                    print("DEBUG: Failed to load analytics from Firestore: \(error)")
                }
        }
    }
}
