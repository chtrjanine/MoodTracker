// File: MoodAnalysisView.swift

import SwiftUI
import AVFoundation

enum AnalysisState {
    case selecting, analyzing, result, error
}

struct MoodAnalysisView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // MARK: - State Variables
    @State private var analysisState: AnalysisState = .selecting
    @State private var selectedImage: UIImage?
    
    // --- Result State ---
    @State private var detectedMood: String = "Neutral"
    @State private var confidence: Float = 0.0
    @State private var analysisError: String? = nil
    
    // --- Debug State ---
    @State private var debugCroppedImage: UIImage? = nil
    @State private var allProbabilities: [String: Float]? = nil
    
    // --- Image Picker State ---
    @State private var showImagePicker = false
    // @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary // REMOVED
    @State private var isCameraActive = false // NEW: Dedicated state for Camera
    
    // --- Permission State ---
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""

    // MARK: - Services
    private let analysisService = MoodAnalysisService()

    var body: some View {
        ZStack {
            switch analysisState {
            case .selecting:
                selectionView
            case .analyzing:
                analyzingView
            case .result:
                resultView
            case .error:
                errorView
            }
        }
        // Sheet for Photo Library
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        // fullScreenCover for Camera (Recommended for Camera UI)
        .fullScreenCover(isPresented: $isCameraActive) {
            ImagePickerView(selectedImage: $selectedImage, sourceType: .camera)
        }
        .onChange(of: selectedImage) { newImage in
            if newImage != nil {
                // Dismiss the sheet/cover before starting analysis
                if showImagePicker { showImagePicker = false }
                if isCameraActive { isCameraActive = false }
                
                Task {
                    await analyzeImage()
                }
            }
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Camera Access Denied"),
                message: Text(permissionAlertMessage),
                primaryButton: .default(Text("Go to Settings"), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }),
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
        .tint(.green)
    }
    
    // MARK: - 1. Selection View
    private var selectionView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "face.smiling.inverse")
                .font(.system(size: 80))
                
            Text("AI Mood Analysis")
                .font(.largeTitle)
                .fontWeight(.bold)
                
            Text("Please select a photo. The AI will analyze your facial expression to identify your mood.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                
            Spacer()
                
            Button(action: {
                checkCameraPermission() // Calls the function that sets isCameraActive
            }) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Take Photo")
                }
                .modifier(PrimaryButtonModifier())
            }
                
            Button(action: {
                // Directly activates the photo library sheet
                self.showImagePicker = true
            }) {
                HStack {
                    Image(systemName: "photo.fill")
                    Text("Choose from Library")
                }
                .modifier(SecondaryButtonModifier())
            }
                
            Button("Cancel") {
                dismiss()
            }
            .padding(.top)
        }
        .padding()
    }

    // MARK: - 2. Analyzing View
    private var analyzingView: some View {
        VStack(spacing: 20) {
            Spacer()
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .frame(maxHeight: 400)
                    .padding()
            }
                
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                
            Text("Analyzing your mood...")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - 3. Result View
    private var resultView: some View {
        MoodAnalysisResultView(
            detectedMood: detectedMood,
            image: selectedImage,
            debugCroppedImage: debugCroppedImage,
            allProbabilities: allProbabilities,
            onSave: { finalMood, notes, date, time in
                saveMoodEntry(mood: finalMood, notes: notes, date: date, time: time)
                dismiss()
            },
            onCancel: {
                dismiss()
            }
        )
    }

    // MARK: - 4. Error View
    private var errorView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
                
            Text("Analysis Failed")
                .font(.largeTitle)
                .fontWeight(.bold)
                
            Text(analysisError ?? "An unknown error occurred.")
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                
            Spacer()
                
            Button(action: {
                resetState()
            }) {
                Text("Try Again")
                    .modifier(PrimaryButtonModifier())
            }
                
            Button("Cancel") {
                dismiss()
            }
            .padding(.top)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private func analyzeImage() async {
        guard let image = selectedImage else { return }
        withAnimation { analysisState = .analyzing }
        
        do {
            let (mood, conf, crop, probs) = try await analysisService.analyzeImage(image)

            print("--- [AI Debug Info] ---")
            print("Best Result: \(mood) (\(conf))")
            print("All Probabilities: \(probs ?? [:])")
            print("----------------------")
            
            DispatchQueue.main.async {
                self.detectedMood = mood
                self.confidence = conf
                self.debugCroppedImage = crop
                self.allProbabilities = probs
                withAnimation { self.analysisState = .result }
            }
        } catch let error as MoodAnalysisService.AnalysisError {
            DispatchQueue.main.async {
                switch error {
                case .noFaceDetected: self.analysisError = "No face detected. Please ensure a clear face is visible in the photo."
                case .multipleFacesDetected: self.analysisError = "Multiple faces detected. Please upload a photo with a single person."
                case .processingError(let underlyingError): self.analysisError = "Image processing failed: \(underlyingError.localizedDescription)"
                case .observationError: self.analysisError = "Could not get analysis results from the model."
                }
                withAnimation { self.analysisState = .error }
            }
        } catch {
            DispatchQueue.main.async {
                self.analysisError = "An unexpected error occurred: \(error.localizedDescription)"
                withAnimation { self.analysisState = .error }
            }
        }
    }
    
    private func resetState() {
        selectedImage = nil
        analysisError = nil
        detectedMood = "Neutral"
        confidence = 0.0
        debugCroppedImage = nil
        allProbabilities = nil
        withAnimation { analysisState = .selecting }
    }
    
    // FIX: Updated checkCameraPermission to use the new isCameraActive state
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.isCameraActive = true

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.isCameraActive = true
                    }
                }
            }
        case .denied, .restricted:
            self.permissionAlertMessage = "MoodTracker needs camera access to take photos for analysis."
            self.showPermissionAlert = true
        @unknown default:
            self.permissionAlertMessage = "An unknown permission issue occurred."
            self.showPermissionAlert = true
        }
    }

    /// Saves the mood entry to the database
    private func saveMoodEntry(mood: String, notes: String, date: Date, time: Date) {
        guard let userID = authViewModel.userSession?.uid else {
            print("DEBUG: Cannot save mood. User not logged in.")
            return
        }
        
        let combinedDate = combineDateTime(date: date, time: time)
        
        let entry = MoodEntry(
            userID: userID,
            date: combinedDate,
            mainMood: mood,
            subMood: nil,
            notes: notes.isEmpty ? "From AI Photo Analysis." : notes
        )
        
        Task {
            do {
                try await DatabaseService.shared.saveMoodEntry(entry, forUserID: userID)
                print("DEBUG: AI mood saved successfully.")
            } catch {
                print("DEBUG: Failed to save AI mood to Firestore: \(error)")
            }
        }
    }
    
    /// Combines separate date and time into a single Date object
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


// MARK: - Result View (Subview)
struct MoodAnalysisResultView: View {
    @State var correctedMood: String
    @State private var notes: String = ""
    
    // State variables for time modification
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    
    let image: UIImage?
    let debugCroppedImage: UIImage?
    let allProbabilities: [String: Float]?
    
    let onSave: (String, String, Date, Date) -> Void
    let onCancel: () -> Void
    
    let allMoods: [String] = [
        "angry", "disgust", "fear", "happy", "neutral", "sad", "surprise"
    ]
    
    let moodEmojis: [String: String] = [
        "happy": "😊", "neutral": "😐", "sad": "😔",
        "angry": "😠", "surprise": "😮", "disgust": "🤢", "fear": "😨"
    ]

    init(detectedMood: String, image: UIImage?, debugCroppedImage: UIImage?, allProbabilities: [String: Float]?, onSave: @escaping (String, String, Date, Date) -> Void, onCancel: @escaping () -> Void) {
        _correctedMood = State(initialValue: detectedMood)
        self.image = image
        self.debugCroppedImage = debugCroppedImage
        self.allProbabilities = allProbabilities
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // --- Card 1: AI Result & Evidence (Remains separate) ---
                    VStack(alignment: .leading, spacing: 16) {
                        
                        VStack(spacing: 8) {
                            Text(moodEmojis[correctedMood, default: "❓"])
                                .font(.system(size: 70))
                                
                            Text("AI thinks your mood is...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                
                            Text(correctedMood.capitalized)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        if let debugCroppedImage = debugCroppedImage {
                            Image(uiImage: debugCroppedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .cornerRadius(8)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 10)
                                
                            if let probs = allProbabilities {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(probs.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(key.capitalized)
                                                    .font(.subheadline)
                                                    .fontWeight(key == correctedMood ? .bold : .regular)
                                                Spacer()
                                                Text(String(format: "%.1f%%", value * 100))
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                            ProgressView(value: value)
                                                .progressViewStyle(LinearProgressViewStyle())
                                                .tint(.green)
                                                .frame(height: 6)
                                        }
                                    }
                                }
                                .padding(.top, 10)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    // --- Card 2: MERGED MODULE (Time + Correction + Notes) ---
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // 1. TIME Section (NEW: Order 1)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Time") // CHANGED TITLE
                                .font(.headline)
                            
                            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            DatePicker("Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        Divider()
                        
                        // 2. CORRECTION Section (Order 2)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI is wrong? change it to:")
                                .font(.headline)
                            
                            Picker("Change Mood", selection: $correctedMood) {
                                ForEach(allMoods, id: \.self) { mood in
                                    Text("\(moodEmojis[mood, default: ""]) \(mood.capitalized)").tag(mood)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        
                        Divider()
                        
                        // 3. NOTES Section (Order 3)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Add Notes (Optional)")
                                .font(.headline)
                            
                            TextEditor(text: $notes)
                                .frame(height: 100)
                                .padding(4)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
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
            .navigationTitle("Analysis Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(correctedMood, notes, selectedDate, selectedTime)
                    }
                }
            }
        }
        .tint(.green)
    }
}


// MARK: - Button Styles

struct PrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}

struct SecondaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(12)
    }
}
