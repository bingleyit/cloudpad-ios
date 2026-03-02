import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email    = ""
    @Published var password = ""
    @Published var name     = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    func login(appState: AppState) async {
        guard validate(needsName: false) else { return }
        isLoading = true; errorMessage = nil
        do {
            let resp = try await APIService.shared.login(email: email, password: password)
            appState.login(token: resp.token, user: resp.user)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func register(appState: AppState) async {
        guard validate(needsName: true) else { return }
        isLoading = true; errorMessage = nil
        do {
            let resp = try await APIService.shared.register(email: email, password: password, name: name)
            appState.login(token: resp.token, user: resp.user)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func validate(needsName: Bool) -> Bool {
        if email.isEmpty || password.isEmpty || (needsName && name.isEmpty) {
            errorMessage = "Please fill in all fields."
            return false
        }
        if !email.contains("@") {
            errorMessage = "Enter a valid email address."
            return false
        }
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return false
        }
        return true
    }
}
