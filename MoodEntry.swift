//  MoodEntry.swift

import Foundation
import FirebaseFirestore

struct MoodEntry: Identifiable, Codable {
    @DocumentID var firestoreID: String? // This will be the document ID from Firestore
    var id: String { firestoreID ?? UUID().uuidString } // Use Firestore ID if available
    
    var userID: String? // To link the entry to a user
    let date: Date
    let mainMood: String
    let subMood: String?
    let notes: String?
    
    // CodingKeys help match Swift properties to Firestore field names
    enum CodingKeys: String, CodingKey {
        case firestoreID = "id"
        case userID
        case date
        case mainMood
        case subMood
        case notes
    }
}
