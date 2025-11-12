// File: DatabaseService.swift

import Foundation
import FirebaseFirestore
import Combine

class DatabaseService {
    
    static let shared = DatabaseService()
    private init() {}
    
    private let db = Firestore.firestore()
    private var moodEntriesCollection: CollectionReference {
        return db.collection("mood_entries")
    }
    
    // Save a mood entry for a specific user
    func saveMoodEntry(_ entry: MoodEntry, forUserID userID: String) async throws {
        // Create a new document in the "mood_entries" collection
        let document = moodEntriesCollection.document()
        
        // Add the userID to the entry before saving
        var entryWithUserID = entry
        entryWithUserID.userID = userID
        
        // Use Codable support to save the object
        try document.setData(from: entryWithUserID)
        print("DEBUG: Mood entry saved to Firestore for user \(userID)")
    }
    
    // Fetch all mood entries for a specific user
    func fetchMoodEntries(forUserID userID: String) async throws -> [MoodEntry] {
        let snapshot = try await moodEntriesCollection
            .whereField("userID", isEqualTo: userID)
            .order(by: "date", descending: true)
            .getDocuments()
            

        var decodedEntries: [MoodEntry] = []
        print("DEBUG: Found \(snapshot.documents.count) documents for user. Attempting to decode...")

        for document in snapshot.documents {
            do {
                var entry = try document.data(as: MoodEntry.self)
                entry.firestoreID = document.documentID
                decodedEntries.append(entry)
                print("  ✅ Successfully decoded document: \(document.documentID)")
            } catch {
                print("  ❌ DECODING FAILED for document: \(document.documentID)")
                print("     Error: \(error)")
                print("     Document data: \(document.data())")
                print("---------------------------------")
            }
        }
        
        print("DEBUG: Finished decoding. Total successful entries: \(decodedEntries.count)")
        return decodedEntries
        
    }
    
    func moodEntriesPublisher(forUserID userID: String) -> AnyPublisher<[MoodEntry], Error> {
        let subject = PassthroughSubject<[MoodEntry], Error>()

        let listener = moodEntriesCollection
            .whereField("userID", isEqualTo: userID)
            .order(by: "date", descending: true)
            .addSnapshotListener { querySnapshot, error in
                
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    subject.send([])
                    return
                }

                let entries = documents.compactMap { doc -> MoodEntry? in
                    try? doc.data(as: MoodEntry.self)
                }
                
                subject.send(entries)
            }
        
        // NOTE: The listener's lifecycle is managed by its attachment to the view model
        // which gets cancelled when the view disappears, so this is safe.

        return subject.eraseToAnyPublisher()
    }
    
    // --- THIS IS WHERE THE FIX IS ---
    // The two functions below were outside the class brace. I've moved them inside.
    
    // Get total entry count for a user
    func getTotalEntriesCount(forUserID userID: String) async -> Int {
        do {
            let snapshot = try await moodEntriesCollection
                .whereField("userID", isEqualTo: userID)
                .getDocuments()
            return snapshot.documents.count
        } catch {
            print("DEBUG: Could not get total entries count: \(error)")
            return 0
        }
    }

    // Clear all data for a user
    func clearAllData(forUserID userID: String) async {
        do {
            let snapshot = try await moodEntriesCollection.whereField("userID", isEqualTo: userID).getDocuments()
            for document in snapshot.documents {
                try await document.reference.delete()
            }
            print("DEBUG: All data cleared for user \(userID)")
        } catch {
            print("DEBUG: Error clearing data: \(error)")
        }
    }
    
}
