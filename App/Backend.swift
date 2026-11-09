import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseMessaging
import WidgetKit

@MainActor
final class PetModel: ObservableObject {
    @Published var snapshot = SharedStore.read()
    @Published var role: Role?
    @Published var meals: [Meal] = []
    @Published var error: String?
    @Published var busy = false
    @Published var invitation: String?
    @Published var ready = false
    @Published var eating = false
    @Published var dancing = false
    private lazy var db = Firestore.firestore()
    private lazy var functions = Functions.functions(region: "us-central1")
    private var profileListener: ListenerRegistration?
    private var listeners: [ListenerRegistration] = []
    private var tokenObserver: NSObjectProtocol?
    private var uid: String? { Auth.auth().currentUser?.uid }

    func connect() async {
        do {
            profileListener?.remove()
            listeners.forEach { $0.remove() }; listeners = []
            if let tokenObserver { NotificationCenter.default.removeObserver(tokenObserver) }
            if Auth.auth().currentUser == nil { _ = try await Auth.auth().signInAnonymously() }
            guard let uid else { return }
            tokenObserver = NotificationCenter.default.addObserver(forName: .messagingTokenChanged, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.registerToken() }
            }
            profileListener = db.collection("users").document(uid).addSnapshotListener { [weak self] doc, failure in
                Task { @MainActor in
                    guard let self else { return }
                    if let failure { self.error = failure.localizedDescription; return }
                    self.ready = true
                    guard let data = doc?.data(), let pair = data["pairID"] as? String,
                          let roleValue = data["role"] as? String, let role = Role(rawValue: roleValue) else {
                        self.role = nil
                        self.meals = []
                        self.snapshot = PetSnapshot()
                        try? await Reminders.schedule(Preferences())
                        SharedStore.clear()
                        WidgetCenter.shared.reloadAllTimelines()
                        return
                    }
                    self.role = role
                    self.watch(pair)
                    await self.registerToken()
                }
            }
        } catch { self.error = error.localizedDescription }
    }
    private func watch(_ pair: String) {
        listeners.forEach { $0.remove() }; listeners = []
        if snapshot.pairID != pair { snapshot = PetSnapshot(pairID: pair); meals = []; persist() }
        listeners.append(db.collection("pairs").document(pair).addSnapshotListener { [weak self] doc, failure in
            Task { @MainActor in
                guard let self else { return }
                if let failure { self.error = failure.localizedDescription; return }
                guard let data = doc?.data() else { return }
                self.snapshot.lastMealAt = (data["lastMealAt"] as? Timestamp)?.dateValue()
                self.snapshot.virtualFedUntil = (data["virtualFedUntil"] as? Timestamp)?.dateValue()
                if let prefs = data["preferences"] as? [String: Any],
                   let json = try? JSONSerialization.data(withJSONObject: prefs),
                   let parsed = try? JSONDecoder().decode(Preferences.self, from: json) {
                    self.snapshot.preferences = parsed
                }
                self.persist()
                if self.role == .child {
                    do { try await Reminders.schedule(self.snapshot.preferences) }
                    catch { self.error = "Meal reminders: \(error.localizedDescription)" }
                }
            }
        })
        listeners.append(db.collection("pairs").document(pair).collection("gifts").order(by: "createdAt", descending: true).limit(to: 100).addSnapshotListener { [weak self] result, failure in
            Task { @MainActor in
                guard let self else { return }
                if let failure { self.error = failure.localizedDescription; return }
                self.snapshot.gifts = result?.documents.compactMap { doc in
                    let d = doc.data()
                    guard let raw = d["food"] as? String, let food = Food(rawValue: raw),
                          let status = d["status"] as? String, let at = d["createdAt"] as? Timestamp else { return nil }
                    return Gift(id: doc.documentID, food: food, status: status, createdAt: at.dateValue(), consumedAt: (d["consumedAt"] as? Timestamp)?.dateValue())
                } ?? []
                self.persist()
            }
        })
        listeners.append(db.collection("pairs").document(pair).collection("meals").order(by: "at", descending: true).limit(to: 50).addSnapshotListener { [weak self] result, failure in
            Task { @MainActor in
                if let failure { self?.error = failure.localizedDescription; return }
                self?.meals = result?.documents.compactMap { doc in
                    guard let at = doc.data()["at"] as? Timestamp, let kind = doc.data()["kind"] as? String else { return nil }
                    return Meal(id: doc.documentID, kind: kind, at: at.dateValue())
                } ?? []
            }
        })
    }
    private func persist() {
        snapshot.updatedAt = Date()
        SharedStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
    func action(_ name: String, _ data: [String: Any] = [:]) async {
        guard !ScreenshotFixtures.active else { return }
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            let result = try await functions.httpsCallable(name).call(data)
            if let response = result.data as? [String: Any], let code = response["code"] as? String { invitation = code }
            if name == "deleteAccount" {
                profileListener?.remove()
                listeners.forEach { $0.remove() }; listeners = []
                try Auth.auth().signOut()
                role = nil; invitation = nil; snapshot = PetSnapshot(); meals = []
                SharedStore.clear(); WidgetCenter.shared.reloadAllTimelines()
                await connect()
            }
            if name == "consumeGift" {
                eating = true
                try? await Task.sleep(for: .seconds(1.2))
                eating = false
            }
        } catch { self.error = error.localizedDescription }
    }
    func savePreferences(_ preferences: Preferences) async {
        do {
            if preferences.remindersEnabled { try await Reminders.requestPermission() }
            let bytes = try JSONEncoder().encode(preferences)
            let data = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] ?? [:]
            await action("savePreferences", ["preferences": data])
        } catch { self.error = error.localizedDescription }
    }
    func registerToken() async {
        guard role != nil, Messaging.messaging().apnsToken != nil else { return }
        do {
            let token = try await Messaging.messaging().token()
            _ = try await functions.httpsCallable("registerDevice").call(["token": token])
        } catch {
            // APNs tokens are unavailable in Simulator; surface device failures in settings.
            self.error = "Push registration: \(error.localizedDescription)"
        }
    }
}
extension Notification.Name { static let messagingTokenChanged = Notification.Name("messagingTokenChanged") }
