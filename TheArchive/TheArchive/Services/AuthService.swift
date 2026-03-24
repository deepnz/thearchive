import AuthenticationServices
import Combine

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var userID: String? = nil

    private let userIDKey = "archive.userID"

    override init() {
        super.init()
        userID = UserDefaults.standard.string(forKey: userIDKey)
        isSignedIn = userID != nil
    }

    // Called on each app foreground — checks credential is still valid
    func checkCredentialState() async {
        guard let userID else {
            isSignedIn = false
            return
        }
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: userID)
            await MainActor.run {
                isSignedIn = (state == .authorized)
                if !isSignedIn { clearSession() }
            }
        } catch {
            await MainActor.run { isSignedIn = false }
        }
    }

    func handleAuthorization(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            UserDefaults.standard.set(credential.user, forKey: userIDKey)
            userID = credential.user
            isSignedIn = true
        case .failure:
            isSignedIn = false
        }
    }

    func signOut() {
        clearSession()
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: userIDKey)
        userID = nil
        isSignedIn = false
    }
}
