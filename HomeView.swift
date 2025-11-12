//  File: HomeView.swift

import SwiftUI
import Combine

struct HomeView: View {
    @State private var showAnalysisSheet = false
    @State private var showHelpSheet = false
    
    @State private var moodEntries: [MoodEntry] = []
    @State private var cancellable: AnyCancellable?
    
    @State private var showAIBubble = true
    
    @AppStorage("selectedTheme") private var selectedTheme = "Green"
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authViewModel: AuthViewModel

    private var adaptiveGreenBackground: Color {
        colorScheme == .dark ? Color.green.opacity(0.15) : Color.green.opacity(0.1)
    }
    
    private var userName: String {
        authViewModel.userSession?.email?.components(separatedBy: "@").first ?? "there"
    }

    // --- Main Body ---
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            navigationContent
            floatingActionButton
        }
        .tint(.green)
    }
    
    // --- Sub-views ---
    
    /// 1. Navigation View Content
    private var navigationContent: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    mainMoodButton
                    moodHistoryList
                    Spacer()
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Hey, \(userName) 👋")
            .onAppear { setupMoodEntriesListener() }
            .onDisappear { cancellable?.cancel() }
            .sheet(isPresented: $showAnalysisSheet) { MoodAnalysisView() }
            .sheet(isPresented: $showHelpSheet) { HelpView() }
        }
    }
    
    /// 2. Main Mood Button
    private var mainMoodButton: some View {
        Button(action: {
            showAnalysisSheet = true
        }) {
            HStack(spacing: 15) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.9))
                
                VStack(alignment: .leading) {
                    // --- CHANGED ---
                    Text("How are you feeling now?") // 文案更改
                    // --- END CHANGED ---
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Use AI Mood Detector")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green)
            .cornerRadius(15)
            .shadow(color: Color.green.opacity(0.4), radius: 5, y: 3)
            
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    /// 3. Mood History List
    private var moodHistoryList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if moodEntries.isEmpty {
                Text("No mood entries yet. AI analysis results will appear here!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 10) {
                    ForEach(moodEntries.prefix(7)) { entry in
                        HStack(spacing: 15) {
                            Text(getMoodEmoji(for: entry.mainMood))
                                .font(.title2)
                                .padding(8)
                                .background(adaptiveGreenBackground)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.mainMood.capitalized)
                                    .font(.headline)
                                Text("\(formatDate(entry.date)) at \(formatTime(entry.date))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    /// 4. Floating Action Button (FAB)
    private var floatingActionButton: some View {
        VStack(alignment: .trailing, spacing: 8) {
            
            if showAIBubble {
                Text("How AI works?")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.9))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 2, y: 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation {
                                showAIBubble = false
                            }
                        }
                    }
            }
            
            Button(action: {
                showHelpSheet = true
            }) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(20)
                    .background(Color.green)
                    .clipShape(Circle())
                    .shadow(radius: 5, x: 0, y: 5)
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 10)
    }
    
    
    // --- Helper Functions ---
    
    func setupMoodEntriesListener() {
        guard let userID = authViewModel.userSession?.uid else {
            print("DEBUG: Cannot setup listener, user not logged in.")
            return
        }
        
        cancellable?.cancel()
        
        self.cancellable = DatabaseService.shared.moodEntriesPublisher(forUserID: userID)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("DEBUG: Error listening to mood entries: \(error.localizedDescription)")
                }
            }, receiveValue: { updatedEntries in
                print("DEBUG: Mood entries updated via listener. New count: \(updatedEntries.count)")
                self.moodEntries = updatedEntries
            })
    }
    
    
    func getMoodEmoji(for mood: String) -> String {
        let moodEmojis: [String: String] = [
            "happy": "😊",
            "sad": "😔",
            "angry": "😠",
            "neutral": "😐",
            "surprise": "😮",
            "disgust": "🤢",
            "fear": "😨"
        ]
        
        return moodEmojis[mood.lowercased()] ?? "❓"
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: Date()) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()), calendar.isDate(date, inSameDayAs: yesterday) { return "Yesterday" }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
