import SwiftUI
import FirebaseAuth

struct AccountLinkView: View {
    @ObservedObject var model: PetModel
    @State private var email = ""
    @State private var password = ""
    @State private var message = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ACCOUNT RECOVERY")
            TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            SecureField("Password (12+ characters)", text: $password)
            Button("Link this account") {
                Task { @MainActor in
                    do {
                        guard let user = Auth.auth().currentUser, user.isAnonymous else { message = "This account is already linked."; return }
                        _ = try await user.link(with: EmailAuthProvider.credential(withEmail: email, password: password))
                        try await user.sendEmailVerification()
                        password = ""; message = "Linked. Check your email for verification."
                    } catch { model.error = error.localizedDescription }
                }
            }.disabled(password.count < 12 || !email.contains("@"))
            Text(message).font(Minimal.font(12))
        }
    }
}
