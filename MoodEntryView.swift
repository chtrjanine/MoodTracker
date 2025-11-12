// File: MoodEntryView.swift
import SwiftUI

// View for logging a mood entry
struct MoodEntryView: View {
    // MARK: - Properties
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Get the current theme from AppStorage
    @AppStorage("selectedTheme") private var selectedTheme = "Green"
    @Environment(\.colorScheme) var colorScheme // <-- ADDED THIS
    
    // State variables to track user selections
    @State private var isCurrentMood = true
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var selectedMood: String = "Happy"
    @State private var selectedSubMood: String = ""
    @State private var notes: String = ""
    
    // ---
    //  FIX IS HERE:
    //  We add the same adaptiveGreenBackground property from HomeView
    // ---
    private var adaptiveGreenBackground: Color {
        colorScheme == .dark ? Color.green.opacity(0.15) : Color.green.opacity(0.1)
    }
    // --- END FIX ---
    
    // Dictionary of available moods
    let moods: [String: (emoji: String, subMoods: [String])] = [
        "Happy": ("😊", ["Joyful", "Grateful", "Content", "Excited", "Hopeful"]),
        "Calm": ("😌", ["Relaxed", "At ease", "Meditation"]),
        "Neutral": ("😐", ["Detached", "Numbed", "Bored", "Normal"]),
        "Sad": ("😔", ["Lonely", "Heartbroken", "Disappointed", "Grieving"]),
        "Stressed": ("😥", ["Anxious", "Overwhelmed", "Worried", "Burned Out"]),
        "Angry": ("😠", ["Irritated", "Frustrated", "Resentful", "Furious"]),
        "Tired": ("😴", ["Sleepy", "No motivation", "Drained", "Burnt Out"]),
        "Sick": ("🤒", ["Cold", "In Pain", "Period", "Other"]),
        "Unknown": ("❓", ["The feelings can't be named"])
    ]

    // MARK: - Body
    var body: some View {
        NavigationView {
            ZStack {
                getBackgroundColor()
                    .ignoresSafeArea(.all)
                
                Form {
                    // Section for current/previous mood toggle
                    Section(header: Text("Is this your current mood?")) {
                        Picker("", selection: $isCurrentMood) {
                            Text("Current").tag(true)
                            Text("Previous").tag(false)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Show date/time pickers only for previous moods
                    if !isCurrentMood {
                        Section(header: Text("When did you feel this way?")) {
                            DatePicker("Select Date", selection: $selectedDate,
                                       displayedComponents: [.date])
                            DatePicker("Select Time", selection: $selectedTime,
                                       displayedComponents: [.hourAndMinute])
                        }
                    }
                    
                    // Mood selection section
                    Section(header: Text("Select Your Mood")) {
                        Picker("Main Mood", selection: $selectedMood) {
                            ForEach(moods.keys.sorted(), id: \.self) { mood in
                                Text("\(moods[mood]?.emoji ?? "") \(mood)")
                                    .tag(mood)
                            }
                        }
                        
                        if let subMoods = moods[selectedMood]?.subMoods, !subMoods.isEmpty {
                            Picker("Optional Detail", selection: $selectedSubMood) {
                                Text("None").tag("")
                                ForEach(subMoods, id: \.self) { subMood in
                                    Text(subMood).tag(subMood)
                                }
                            }
                        }
                    }
                    
                    // Notes section
                    Section(header: Text("Add Notes (Optional)")) {
                        TextEditor(text: $notes)
                            .frame(height: 100)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Log Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMoodEntry()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .preferredColorScheme(getColorScheme())
        }
    }
    
    // MARK: - Functions
    
    private func getColorScheme() -> ColorScheme? {
        switch selectedTheme {
        case "Dark":
            return .dark
        default:
            return nil
        }
    }
    
    private func getBackgroundColor() -> Color {
        switch selectedTheme {
        case "Dark":
            return Color.black
        default:
            // ---
            //  FIX IS HERE:
            //  Now it calls the property, not Color.
            // ---
            return adaptiveGreenBackground
            // --- END FIX ---
        }
    }
    
    // Saves the current mood entry to Firestore
    func saveMoodEntry() {
        guard let userID = authViewModel.userSession?.uid else {
            print("DEBUG: Cannot save mood. User not logged in.")
            return
        }
        
        let entry = MoodEntry(
            userID: userID,
            date: isCurrentMood ? Date() : combineDateTime(date: selectedDate, time: selectedTime),
            mainMood: selectedMood,
            subMood: selectedSubMood.isEmpty ? nil : selectedSubMood,
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            do {
                try await DatabaseService.shared.saveMoodEntry(entry, forUserID: userID)
            } catch {
                print("DEBUG: Failed to save mood to Firestore: \(error)")
            }
        }
    }
    
    // Combines separate date and time into a single Date object
    func combineDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        
        return calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: timeComponents.hour,
            minute: timeComponents.minute,
            second: timeComponents.second
        )) ?? Date()
    }
}
