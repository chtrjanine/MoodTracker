import SwiftUI
import Vision
import CoreML
import ImageIO

class MoodAnalysisService {
    
    private let FACE_CONFIDENCE_THRESHOLD: Float = 0.5
    
    enum AnalysisError: Error {
        case noFaceDetected
        case multipleFacesDetected
        case processingError(Error)
        case observationError
    }
    
    // MARK: - Core ML Model
    
    private let model: VNCoreMLModel = {
        do {
            let coreMLModel = try MobileViT_v2_Correct_EMA(configuration: MLModelConfiguration())
            return try VNCoreMLModel(for: coreMLModel.model)
        } catch {
            fatalError("Failed to load Core ML model: \(error).")
        }
    }()
    
    private let context = CIContext()

    // MARK: - Model Output Labels
    
    // The order of this array *must* match the A-Z alphabetical order
    // of the training data folders. This has been verified as correct.
    private let emotionLabels = [
        "angry",
        "disgust",
        "fear",
        "happy",
        "neutral",
        "sad",
        "surprise"
    ]

    // MARK: - Main Analysis Function
    
    func analyzeImage(_ uiImage: UIImage) async throws -> (mood: String, confidence: Float, debugCrop: UIImage?, allProbabilities: [String: Float]) {
        
        guard let cgImage = uiImage.cgImage else {
            throw AnalysisError.processingError(NSError(domain: "ImageConversion", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert UIImage to CGImage."]))
        }
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        
        let orientation = CGImagePropertyOrientation(uiImage.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        
        do {
            // --- Stage 1: Detect Faces ---
            try handler.perform([faceDetectionRequest])
            
            guard let allFaceObservations = faceDetectionRequest.results else {
                throw AnalysisError.noFaceDetected
            }
            let highConfidenceFaces = allFaceObservations.filter { $0.confidence > FACE_CONFIDENCE_THRESHOLD }
            
            guard !highConfidenceFaces.isEmpty else {
                print("[Debug] No faces detected with confidence higher than \(FACE_CONFIDENCE_THRESHOLD).")
                throw AnalysisError.noFaceDetected
            }
            
            guard highConfidenceFaces.count == 1 else {
                print("[Debug] Detected \(highConfidenceFaces.count) faces, rejecting.")
                throw AnalysisError.multipleFacesDetected
            }
            
            let faceObservation = highConfidenceFaces[0]
            print("[Debug] Detected 1 face with confidence: \(faceObservation.confidence)")
            
            // --- Stage 2: Crop Face ---
            let boundingBox = scaleBoundingBox(faceObservation.boundingBox, scale: 1.2)
            let ciImage = CIImage(cgImage: cgImage)
            let faceImageRect = VNImageRectForNormalizedRect(boundingBox, Int(ciImage.extent.width), Int(ciImage.extent.height))
            let croppedCIImage = ciImage.cropped(to: faceImageRect)

            var debugCroppedImage: UIImage? = nil
            let orientedCroppedCIImage = croppedCIImage.oriented(orientation)
            if let cgImg = context.createCGImage(orientedCroppedCIImage, from: orientedCroppedCIImage.extent) {
                debugCroppedImage = UIImage(cgImage: cgImg)
            }

            // --- Stage 3: Analyze the Cropped Face ---
            let faceClassificationRequest = VNCoreMLRequest(model: model)
            
            // [ THE FINAL FIX ]
            // This forces the request to scale the cropped image while preserving
            // its aspect ratio (matching the training config), rather than
            // stretching/squashing it (the default 'scaleFill').
            faceClassificationRequest.imageCropAndScaleOption = .centerCrop

            let faceHandler = VNImageRequestHandler(ciImage: croppedCIImage, orientation: orientation)
            try faceHandler.perform([faceClassificationRequest])
            
            // --- Stage 4: Interpret Logits Output ---
            guard let results = faceClassificationRequest.results as? [VNCoreMLFeatureValueObservation] else {
                print("[Error] Failed to cast results to VNCoreMLFeatureValueObservation.")
                throw AnalysisError.observationError
            }
            
            guard let firstResult = results.first else {
                print("[Error] No results found in VNCoreMLFeatureValueObservation array.")
                throw AnalysisError.observationError
            }
            
            // Check your .mlpackage file in Xcode for this output name (e.g., 'var_1259')
            guard let logitsMultiArray = firstResult.featureValue.multiArrayValue else {
                print("[Error] Failed to get MLMultiArray from feature value.")
                throw AnalysisError.observationError
            }
            
            let probabilities = softmax(logitsMultiArray)
            
            guard !probabilities.isEmpty else {
                print("[Error] Softmax function returned an empty array.")
                throw AnalysisError.observationError
            }

            guard let (topIndex, topConfidence) = probabilities.enumerated().max(by: { $0.element < $1.element }) else {
                print("[Error] Could not find max probability (argmax failed).")
                throw AnalysisError.observationError
            }
            
            let topMood = emotionLabels[topIndex]
            
            var allProbabilities: [String: Float] = [:]
            for (index, probability) in probabilities.enumerated() {
                let label = emotionLabels[index]
                allProbabilities[label] = Float(probability)
            }
            
            return (topMood, Float(topConfidence), debugCroppedImage, allProbabilities)

        } catch let error as AnalysisError {
            throw error
        } catch {
            throw AnalysisError.processingError(error)
        }
    }
    
    /// Scales a CGRect proportionally while maintaining its center point.
    private func scaleBoundingBox(_ box: CGRect, scale: CGFloat) -> CGRect {
        let x = box.origin.x + box.width / 2
        let y = box.origin.y + box.height / 2
        let newWidth = box.width * scale
        let newHeight = box.height * scale
        
        let newRect = CGRect(
            x: x - (newWidth / 2),
            y: y - (newHeight / 2),
            width: newWidth,
            height: newHeight
        )
        
        let unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        return newRect.standardized.intersection(unitRect)
    }
}

// MARK: - Extensions

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}


private func softmax(_ x: MLMultiArray) -> [Double] {
    guard x.dataType == .double || x.dataType == .float32 else {
        print("Error: MLMultiArray is not Float32 or Double.")
        return []
    }

    let count = x.count
    let pointer = x.dataPointer.bindMemory(to: Float32.self, capacity: count)

    var maxVal: Float32 = -Float32.greatestFiniteMagnitude
    for i in 0..<count {
        if pointer[i] > maxVal {
            maxVal = pointer[i]
        }
    }

    var sum: Double = 0.0
    var expValues = [Double](repeating: 0.0, count: count)
    
    for i in 0..<count {
        let expVal = exp(Double(pointer[i] - maxVal))
        expValues[i] = expVal
        sum += expVal
    }

    let probabilities = expValues.map { $0 / sum }
    return probabilities
}
