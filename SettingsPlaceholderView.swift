// File: SettingsPlaceholderView.swift

import SwiftUI

struct SettingsView: View {
    // MARK: - Properties
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = false
    @AppStorage("reminderTime") private var reminderTimeData = Data()
    @AppStorage("selectedTheme") private var selectedTheme = "Default"
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // State for UI updates
    @State private var reminderTime = Date()
    @State private var showingExportSheet = false
    // @State private var showingDataAlert = false // REMOVED
    // @State private var showingContactSheet = false // REMOVED
    // @State private var showingHelpSheet = false // REMOVED
    @State private var totalEntries = 0
    @State private var showingSignOutAlert = false

    let themes = ["Light", "Dark"]
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            List {
                // Account Section
                Section("Account") {
                    HStack {
                        Text("Logged In As")
                        Spacer()
                        Text(authViewModel.userSession?.email ?? "N/A")
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Button("Sign Out", role: .destructive) {
                        showingSignOutAlert = true
                    }
                }
                
                // Notifications Section
                Section("Notifications") {
                    Toggle("Daily Reminder", isOn: $dailyReminderEnabled)
                        .tint(.green)
                    
                    if dailyReminderEnabled {
                        DatePicker("Reminder Time",
                                 selection: $reminderTime,
                                 displayedComponents: .hourAndMinute)
                            .onChange(of: reminderTime) { _, newValue in
                                saveReminderTime(newValue)
                            }
                    }
                }
                
                // Appearance Section
                Section("Appearance") {
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(themes, id: \.self) { theme in
                            Text(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Data Management Section
                Section("Data Management") {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                        Button("Export Data") {
                            showingExportSheet = true
                        }
                        .foregroundColor(.primary)
                        Spacer()
                    }
                    
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Entries")
                        Spacer()
                        Text("\(totalEntries)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Support Section
                Section("Support") {

                    Link(destination: URL(string: "mailto:chtrjanine@gmail.com")!) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                            Text("Contact Support")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }

            .navigationTitle("Settings")
            .onAppear {
                loadReminderTime()
                fetchTotalEntries()
            }
            // REMOVED: .alert for "Clear All Data"
            .sheet(isPresented: $showingExportSheet) {
                if let userId = authViewModel.userSession?.uid {
                    ExportDataView(userID: userId)
                }
            }
            // REMOVED: .sheet for HelpView
            // REMOVED: .sheet for ContactSupportView
            .alert("Confirm Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authViewModel.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out? You will be returned to the login screen.")
            }
            .preferredColorScheme(getColorScheme())
        }
    }
    
    // MARK: - Functions
    private func getColorScheme() -> ColorScheme? {
        selectedTheme == "Dark" ? .dark : nil
    }
    
    // REMOVED: getBackgroundColor()
    
    private func saveReminderTime(_ time: Date) {
        if let encoded = try? JSONEncoder().encode(time) {
            reminderTimeData = encoded
        }
    }
    
    private func loadReminderTime() {
        if let decoded = try? JSONDecoder().decode(Date.self, from: reminderTimeData) {
            reminderTime = decoded
        } else {
            let calendar = Calendar.current
            let components = DateComponents(hour: 20, minute: 0)
            reminderTime = calendar.date(from: components) ?? Date()
        }
    }
    
    private func fetchTotalEntries() {
        guard let userID = authViewModel.userSession?.uid else { return }
        Task {
            self.totalEntries = await DatabaseService.shared.getTotalEntriesCount(forUserID: userID)
        }
    }
    
}


struct ExportDataView: View {
    @Environment(\.presentationMode) var presentationMode
    let userID: String
    
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportedFileURL: URL?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Export Your Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Export your mood tracking data as a CSV file")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await exportData()
                    }
                }) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isExporting ? "Exporting..." : "Export Data")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isExporting)
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.secondary)
                .padding(.top, 8)
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingShareSheet) {
                if let fileURL = exportedFileURL {
                    ShareSheet(activityItems: [fileURL])
                }
            }
        }
    }
    
    private func exportData() async {
        isExporting = true
        
        do {
            let csvData = try await createCSVData()
            
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("mood_data_\(Date().timeIntervalSince1970).csv")
            
            try csvData.write(to: tempURL, atomically: true, encoding: .utf8)
            self.exportedFileURL = tempURL
            self.isExporting = false
            self.showingShareSheet = true
        } catch {
            print("Error writing CSV file: \(error)")
            self.isExporting = false
        }
    }
    
    private func createCSVData() async throws -> String {
        var csvString = "Date,Main Mood,Sub Mood,Notes\n"
        
        let entries = try await DatabaseService.shared.fetchMoodEntries(forUserID: userID)
            
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        for entry in entries {
            let dateString = dateFormatter.string(from: entry.date)
            let mainMood = entry.mainMood
            let subMood = entry.subMood ?? ""
            let notes = entry.notes?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            csvString += "\"\(dateString)\",\"\(mainMood)\",\"\(subMood)\",\"\(notes)\"\n"
        }
        
        return csvString
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthViewModel())
    }
}
