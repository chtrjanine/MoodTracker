// File: HelpView.swift

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // --- Card 1: How to Use ---
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How to Use")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                Image(systemName: "1.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Text("Tap the main button on the Home screen to open the AI analyzer.")
                            }
                            
                            HStack(alignment: .top) {
                                Image(systemName: "2.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Text("Upload a clear photo of your face or take a new one.")
                            }
                            
                            HStack(alignment: .top) {
                                Image(systemName: "3.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Text("The AI will analyze your expression and show you the result.")
                            }
                            
                            HStack(alignment: .top) {
                                Image(systemName: "4.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                Text("Confirm the mood, add notes if you like, and save!")
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    
                    // --- Card 2: Example Result (效果展示) ---
                    VStack(alignment: .leading, spacing: 16) {
                        
                        Text("Example: Analysis Result")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Group 1: Main Result
                        VStack(spacing: 8) {
                            Text("😊")
                                .font(.system(size: 70))
                            Text("AI thinks your mood is...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Happy")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        // --- CHANGED: Removed the example image ---
                        // Image was here, now removed.
                        
                        // Group 3: Probabilities (Mock-up with 7 moods)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("This is what the AI sees:")
                                .font(.headline)
                                .padding(.bottom, 5)

                            // Mocked data for the example, now with 7 moods
                            ProgressBarExample(mood: "Happy", value: 0.90, isTop: true)
                            ProgressBarExample(mood: "Neutral", value: 0.05, isTop: false)
                            ProgressBarExample(mood: "Surprise", value: 0.02, isTop: false)
                            ProgressBarExample(mood: "Sad", value: 0.01, isTop: false)
                            ProgressBarExample(mood: "Angry", value: 0.01, isTop: false)
                            ProgressBarExample(mood: "Disgust", value: 0.005, isTop: false)
                            ProgressBarExample(mood: "Fear", value: 0.005, isTop: false)
                        }
                        .padding(.top, 10) // Added padding for spacing since image is gone
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("How AI Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .tint(.green)
    }
}

// A small helper view for the "Example" card
struct ProgressBarExample: View {
    let mood: String
    let value: Float
    let isTop: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(mood)
                    .font(.subheadline)
                    .fontWeight(isTop ? .bold : .regular)
                Spacer()
                Text(String(format: "%.0f%%", value * 100))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: value)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(isTop ? .green : .gray.opacity(0.5))
                .frame(height: 6)
        }
    }
}

// Preview for HelpView
struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}
