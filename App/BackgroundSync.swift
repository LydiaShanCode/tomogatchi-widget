import Foundation
import FirebaseAuth
import FirebaseFirestore
import WidgetKit

@MainActor
enum BackgroundSync {
    static func refresh() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        let db = Firestore.firestore()
        do {
            let profile = try await db.collection("users").document(uid).getDocument()
            guard let pair = profile.data()?["pairID"] as? String else { return false }
            async let pairDoc = db.collection("pairs").document(pair).getDocument()
            async let giftDocs = db.collection("pairs").document(pair).collection("gifts").order(by: "createdAt", descending: true).limit(to: 100).getDocuments()
            let (pet, gifts) = try await (pairDoc, giftDocs)
            var state = PetSnapshot(pairID: pair)
            let data = pet.data() ?? [:]
            state.lastMealAt = (data["lastMealAt"] as? Timestamp)?.dateValue()
            state.virtualFedUntil = (data["virtualFedUntil"] as? Timestamp)?.dateValue()
            if let prefs = data["preferences"], let bytes = try? JSONSerialization.data(withJSONObject: prefs), let p = try? JSONDecoder().decode(Preferences.self, from: bytes) { state.preferences = p }
            state.gifts = gifts.documents.compactMap { doc in
                let d = doc.data()
                guard let foodName = d["food"] as? String, let food = Food(rawValue: foodName), let status = d["status"] as? String, let at = d["createdAt"] as? Timestamp else { return nil }
                return Gift(id: doc.documentID, food: food, status: status, createdAt: at.dateValue(), consumedAt: (d["consumedAt"] as? Timestamp)?.dateValue())
            }
            SharedStore.write(state)
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch { return false }
    }
}
