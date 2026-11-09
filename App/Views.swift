import SwiftUI
import FirebaseAuth

struct ConnectedRoot: View {
    @StateObject private var model = ScreenshotFixtures.makeModel()
    @State private var settings = false
    @State private var giftScreen = false
    @State private var widgetGallery = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        NavigationStack {
            Group {
                if !model.ready { ProgressView("Connecting") }
                else if model.role == nil { PairingView(model: model) }
                else if model.role == .parent { FriendsHome(model: model) }
                else { Dashboard(model: model, showGift: $giftScreen) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(model.role == .parent ? .hidden : .visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .principal) { Text("FEED CONNOR").font(Minimal.font()) } }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Widgets") { widgetGallery = true } }
                if model.role != nil {
                    ToolbarItem(placement: .topBarTrailing) { Button("Settings") { settings = true } }
                }
            }
            .sheet(isPresented: $widgetGallery) { WidgetGallery() }
            .sheet(isPresented: $settings) { SettingsView(model: model) }
            .sheet(isPresented: $giftScreen) { GiftInteraction(model: model) }
            .alert("FEED CONNOR", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
        }
        .task { if !ScreenshotFixtures.active { await model.connect() } }
        .onOpenURL { url in
            if url.host == "gift" { giftScreen = true }
            if url.host == "dance" { model.dancing = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: SharedStore.consoleActionNotification).receive(on: RunLoop.main)) { _ in handleConsoleAction() }
        .onChange(of: model.ready) { _, _ in handleConsoleAction() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            // App Intents may finish just after foreground activation. This brief
            // cancellable handoff catches the App Group write from either process.
            for _ in 0..<10 {
                handleConsoleAction()
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, model.role != nil, !ScreenshotFixtures.active { Task { _ = await BackgroundSync.refresh() } }
        }
    }
    private func handleConsoleAction() {
        guard model.ready, let action = SharedStore.takeConsoleAction() else { return }
        settings = false
        widgetGallery = false
        switch action {
        case .eat: giftScreen = true
        case .dance:
            giftScreen = false
            model.dancing = true
        }
    }
}
struct PairingView: View {
    @ObservedObject var model: PetModel
    @State private var role: Role = .parent
    @State private var code = ""
    @State private var email = ""
    @State private var password = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Text("Two people. One Connor.")
                TextField("Existing account email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Password", text: $password)
                Button("Restore linked account") {
                    Task { @MainActor in
                        do {
                            _ = try await Auth.auth().signIn(withEmail: email, password: password)
                            password = ""
                            await model.connect()
                        } catch { model.error = error.localizedDescription }
                    }
                }.disabled(email.isEmpty || password.isEmpty)
                Button("Reset password") {
                    Task {
                        do { try await Auth.auth().sendPasswordReset(withEmail: email) }
                        catch { model.error = error.localizedDescription }
                    }
                }.disabled(email.isEmpty)
                HStack(spacing: 24) {
                    Button(role == .parent ? "[Lydia · parent]" : "Lydia · parent") { role = .parent }
                    Button(role == .child ? "[Connor · child]" : "Connor · child") { role = .child }
                }
                Button("Create private pair") { Task { await model.action("createPair", ["role": role.rawValue]) } }
                Text("Or enter the code from your partner.").multilineTextAlignment(.center)
                TextField("Pairing code", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled().textFieldStyle(.plain).padding(12).overlay(Rectangle().stroke(.black, lineWidth: 1))
                Button("Join pair") { Task { await model.action("joinPair", ["code": code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()]) } }
                    .disabled(code.count != 12)
                Text("Joining takes the other role. Codes expire in 15 minutes and work once. Keep yours private.")
                    .font(Minimal.font(12)).multilineTextAlignment(.center)
            }.padding(32).disabled(model.busy)
        }
    }
}
struct AnimatedPet: View {
    let state: PetSnapshot
    var eating = false
    var dancing = false
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: ScreenshotFixtures.active && !dancing)) { context in
            let mood: Mood = eating ? .fed : state.bodyMood(at: context.date)
            let animation = BodyAnimation.resolve(mood: mood, dancing: dancing && !eating)
            let frame = ScreenshotFixtures.active && !dancing ? 1 : animation.frame(at: context.date.timeIntervalSince1970)
            VStack(spacing: 20) {
                CharacterView(mood: mood, frame: frame, food: eating ? nil : state.pendingGift?.food, animation: animation)
                    .frame(height: 250)
                    .scaleEffect(eating ? 1.04 : 1)
                    .animation(.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true), value: eating)
                Text(state.displayMood(at: context.date).rawValue).font(Minimal.font(18))
            }
        }
    }
}
struct Dashboard: View {
    @ObservedObject var model: PetModel
    @Binding var showGift: Bool
    @State private var food: Food = .apple
    @State private var mealKind = "Lunch"
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                AnimatedPet(state: model.snapshot, eating: model.eating, dancing: model.dancing)
                if let code = model.invitation {
                    Text("PAIRING CODE\n\(code)\nExpires in 15 minutes").multilineTextAlignment(.center).textSelection(.enabled)
                    ShareLink(item: "FEED CONNOR pairing code: \(code)") { Text("Share code privately") }
                }
                if model.role == .parent {
                    ParentDetails(state: model.snapshot)
                    Picker("Food", selection: $food) {
                        ForEach(Food.allCases) { food in Text("\(food.icon) \(food.name)").tag(food) }
                    }.pickerStyle(.menu)
                    Button("Send") { Task { await model.action("sendGift", ["food": food.rawValue, "requestID": UUID().uuidString]) } }
                    GiftHistory(gifts: model.snapshot.gifts)
                } else {
                    HStack(spacing: 40) {
                        Button { showGift = true } label: {
                            Text("EAT").frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Eat gift")
                        .disabled(model.snapshot.pendingGift == nil)
                        Button { model.dancing = true } label: {
                            Image(systemName: "star.fill").font(.system(size: 22, weight: .regular))
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Dance")
                        .accessibilityIdentifier("danceButton")
                        .disabled(model.dancing)
                    }
                    Picker("Meal", selection: $mealKind) {
                        ForEach(["Breakfast", "Lunch", "Dinner", "Snack"], id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                    Button("Confirm real meal") { Task { await model.action("logMeal", ["kind": mealKind, "requestID": UUID().uuidString]) } }
                    Text("Virtual food never logs a real meal.").font(Minimal.font(12))
                    if !model.meals.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("MEAL HISTORY")
                            ForEach(model.meals) { meal in
                                HStack { Text(meal.kind); Spacer(); Text(meal.at, format: .dateTime.month().day().hour().minute()) }
                            }
                        }
                    }
                }
            }.padding(28).disabled(model.busy)
        }
        .task(id: model.dancing) {
            guard model.dancing else { return }
            do {
                try await Task.sleep(for: .seconds(3))
                model.dancing = false
            } catch { /* SwiftUI cancels this task when the view disappears. */ }
        }
        .onDisappear { model.dancing = false }
    }
}
struct ParentDetails: View {
    let state: PetSnapshot
    var body: some View {
        VStack(spacing: 16) {
            if let last = state.lastMealAt { Text("Last meal: \(last.formatted(date: .abbreviated, time: .shortened))") }
            else { Text("No confirmed meals yet") }
            Text(state.pendingGift == nil ? "No pending gifts" : "Gift waiting for Connor")
        }.multilineTextAlignment(.center)
    }
}
struct GiftHistory: View {
    let gifts: [Gift]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("GIFTS")
            ForEach(gifts) { gift in
                HStack {
                    Text("\(gift.food.icon) \(gift.food.name)")
                    Spacer()
                    Text(gift.status)
                }.accessibilityElement(children: .combine)
            }
        }
    }
}
struct GiftInteraction: View {
    @ObservedObject var model: PetModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 32) {
            AnimatedPet(state: model.snapshot, eating: model.eating)
            if let gift = model.snapshot.pendingGift, model.role == .child {
                Text("\(gift.food.name) from Lydia")
                HStack(spacing: 48) {
                    Button("Eat") {
                        Task {
                            await model.action("consumeGift", ["giftID": gift.id])
                            if model.error == nil { dismiss() }
                        }
                    }
                    Button("Later") { dismiss() }
                }.disabled(model.busy)
                Text("A virtual gift. Confirm real meals separately.").font(Minimal.font(12)).multilineTextAlignment(.center)
            } else { Text("No pending gift"); Button("Done") { dismiss() } }
        }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(.white)
            .font(Minimal.font()).foregroundStyle(.black).tint(.black).preferredColorScheme(.light)
    }
}
struct SettingsView: View {
    @ObservedObject var model: PetModel
    @Environment(\.dismiss) private var dismiss
    @State private var prefs = Preferences()
    @State private var confirmDeletion = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(model.role == .parent ? "LYDIA · PARENT" : "CONNOR · CHILD")
                    if model.role == .child {
                        ForEach($prefs.schedules) { $schedule in
                            VStack(alignment: .leading) {
                                Toggle(schedule.id, isOn: $schedule.enabled)
                                HStack {
                                    Picker("Hour", selection: $schedule.hour) { ForEach(0..<24) { Text(String(format: "%02d", $0)).tag($0) } }
                                    Picker("Minute", selection: $schedule.minute) { ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) } }
                                }
                            }
                        }
                        Stepper("Hungry after \(Int(prefs.hungryAfterHours)) hours", value: $prefs.hungryAfterHours, in: 1...12)
                            .onChange(of: prefs.hungryAfterHours) { _, hours in prefs.tiredAfterHours = max(prefs.tiredAfterHours, hours + 1) }
                        Stepper("Tired after \(Int(prefs.tiredAfterHours)) hours", value: $prefs.tiredAfterHours, in: (prefs.hungryAfterHours + 1)...24)
                        Toggle("Meal reminders", isOn: $prefs.remindersEnabled)
                        Picker("Quiet from", selection: $prefs.quietStart) { ForEach(0..<24) { Text("\($0):00").tag($0) } }
                        Picker("Quiet until", selection: $prefs.quietEnd) { ForEach(0..<24) { Text("\($0):00").tag($0) } }
                        Text("Equal quiet-hour values turn quiet hours off. Up to four meal reminders daily. Gift pushes respect Connor’s quiet hours.")
                        Button("Save meal settings") { Task { prefs.timeZone = TimeZone.current.identifier; await model.savePreferences(prefs); if model.error == nil { dismiss() } } }
                    }
                    Button("Enable gift notifications") {
                        Task {
                            do { try await Reminders.requestPermission(); await model.registerToken() }
                            catch { model.error = error.localizedDescription }
                        }
                    }
                    Button("New pairing code") { Task { await model.action("createInvite") } }
                    if let code = model.invitation { Text(code).textSelection(.enabled) }
                    Text("Codes only work while the second role is empty. Anonymous accounts stay on this device. Link an email before reinstalling.")
                    AccountLinkView(model: model)
                    Button("Delete account and shared pair data") { confirmDeletion = true }
                        .alert("Delete this account?", isPresented: $confirmDeletion) {
                            Button("Cancel", role: .cancel) { }
                            Button("Delete", role: .destructive) {
                                Task { await model.action("deleteAccount"); if model.error == nil { dismiss() } }
                            }
                        } message: { Text("This permanently removes your account, all shared meals and gifts, and unpairs your partner. Their login account remains.") }
                    Text("Widget data refreshes when this app syncs or iOS delivers a background push. iOS controls widget refresh timing.")
                }.padding(28).disabled(model.busy)
            }.background(.white).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .principal) { Text("Settings").font(Minimal.font()) } }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.onAppear { prefs = model.snapshot.preferences }
            .font(Minimal.font()).foregroundStyle(.black).tint(.black).preferredColorScheme(.light)
    }
}
#if DEBUG
#Preview("Lydia dashboard") {
    VStack(spacing: 28) {
        AnimatedPet(state: previewSnapshot(.hungry))
        ParentDetails(state: previewSnapshot(.hungry))
        Text("🍎 Apple     Send").font(Minimal.font())
    }.padding().background(.white).foregroundStyle(.black)
}
func previewSnapshot(_ mood: Mood) -> PetSnapshot {
    var state = PetSnapshot()
    state.preferences.schedules = []
    state.lastMealAt = Date().addingTimeInterval(mood == .tired ? -28800 : mood == .hungry ? -18000 : 0)
    if mood == .gift { state.gifts = [Gift(id: "preview", food: .apple, status: "pending", createdAt: Date())] }
    return state
}
#endif

/// The linked-friend home. Gifts are sent through the existing server action;
/// only the recipient can consume them.
struct FriendsHome: View {
    @ObservedObject var model: PetModel
    @State private var selected: Food = .apple
    @State private var invite = false
    @State private var details = false
    @State private var sent = false
    private let menu: [Food] = [.apple, .bokChoy, .steak, .cake, .croissant]

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 18) {
                        Button("CONNER") { details = true }
                            .accessibilityLabel("Conner, selected friend. Open details")
                        Spacer(minLength: 12)
                        Button { invite = true } label: {
                            Label("ADD FRIEND", systemImage: "plus")
                        }
                    }
                    .font(Minimal.font(13)).frame(minHeight: 44)
                    .padding(.horizontal, 30)

                    Spacer(minLength: 65)
                    VStack(spacing: 12) {
                        Text("CONNER CHYUNG").font(Minimal.font(22))
                        VStack(spacing: 3) {
                            Text("“A LITERAL CHILD”")
                            Text(lastMeal)
                        }.font(Minimal.font(12)).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 48)

                    TimelineView(.animation(minimumInterval: 0.12, paused: ScreenshotFixtures.active && !model.dancing)) { context in
                        let animation = BodyAnimation.resolve(mood: model.snapshot.bodyMood(at: context.date), dancing: model.dancing)
                        MiniConsoleView(state: model.snapshot, date: context.date,
                            frame: ScreenshotFixtures.active ? 1 : animation.frame(at: context.date.timeIntervalSince1970),
                            animation: animation) {
                                Button { details = true } label: { Color.clear }
                                    .accessibilityLabel("View Conner’s pending gifts")
                            } starControl: {
                                Button { model.dancing = true } label: { Color.clear }
                                    .accessibilityLabel("Dance").accessibilityIdentifier("danceButton")
                            }
                    }
                    .frame(width: min(geometry.size.width * 0.8, 430), height: min(geometry.size.width * 0.9, 480))

                    HStack(spacing: 12) {
                        ForEach(menu) { food in
                            Button { selected = food; sent = false } label: {
                                Image(food.artwork).resizable().interpolation(.none).scaledToFit()
                                    .frame(width: 34, height: 34)
                                    .saturation(selected == food ? 1 : 0)
                                    .opacity(selected == food ? 1 : 0.65)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel(food.name)
                            .accessibilityAddTraits(selected == food ? .isSelected : [])
                        }
                    }.padding(.top, 25)
                    Button {
                        Task {
                            await model.action("sendGift", ["food": selected.rawValue, "requestID": UUID().uuidString])
                            if model.error == nil { sent = true }
                        }
                    } label: {
                        Text(sent ? "GIFT SENT · WAITING TO BE EATEN" : "SEND \(selected.name.uppercased()) ↗")
                            .font(Minimal.font(15)).frame(minHeight: 44)
                    }.accessibilityIdentifier("sendGiftButton")
                    .disabled(model.busy).padding(.top, 30)
                    Spacer(minLength: 65)
                }.frame(minHeight: geometry.size.height)
                    .frame(maxWidth: .infinity)
            }.background(Color(white: 0.97))
        }
        .foregroundStyle(Color(white: 0.3)).tint(Color(white: 0.3))
        .sheet(isPresented: $invite) {
            NavigationStack {
                VStack(spacing: 24) {
                    Text("Your linked friend is Conner.")
                    Text("This account supports one private pair. Share an invite when the other role is empty.")
                        .multilineTextAlignment(.center)
                    Button("Create pairing invite") { Task { await model.action("createInvite") } }
                        .disabled(model.busy)
                    if let code = model.invitation {
                        Text(code).textSelection(.enabled)
                        ShareLink(item: "FEED CONNOR pairing code: \(code)")
                    }
                }.padding(30).font(Minimal.font())
                    .toolbar { Button("Done") { invite = false } }
            }
        }
        .sheet(isPresented: $details) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 28) {
                        ParentDetails(state: model.snapshot)
                        GiftHistory(gifts: model.snapshot.gifts)
                        NavigationLink("Settings") { SettingsView(model: model) }
                        NavigationLink("Widgets") { WidgetGallery() }
                    }.padding(28)
                }.font(Minimal.font()).navigationTitle("Conner")
                    .toolbar { Button("Done") { details = false } }
            }
        }
        .task(id: model.dancing) {
            guard model.dancing else { return }
            do { try await Task.sleep(for: .seconds(3)); model.dancing = false }
            catch { model.dancing = false }
        }
        .onDisappear { model.dancing = false }
    }

    private var lastMeal: String {
        guard let date = model.snapshot.lastMealAt else { return "NO CONFIRMED MEALS YET" }
        let hours = max(0, Int(Date().timeIntervalSince(date) / 3600))
        return hours == 0 ? "LAST SEEN EATING LESS THAN 1 HR AGO" : "LAST SEEN EATING \(hours) HRS AGO"
    }
}
