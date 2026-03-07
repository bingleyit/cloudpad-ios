import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = AuthViewModel()
    @State private var mode: Mode = .login

    enum Mode { case login, register }

    var body: some View {
        ZStack {
            Color(hex: "#f7f4f0").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Logo
                    VStack(spacing: 10) {
                        Text("☁️")
                            .font(.inter(56))

                        Text("cloudpad")
                            .font(.caveat(42, weight: .bold))
                            .foregroundColor(appState.accentColor)

                        Text("Your pad, your mood")
                            .font(.inter(13))
                            .foregroundColor(Color(hex: "#9a9490"))
                    }
                    .padding(.top, 80)
                    .padding(.bottom, 44)

                    // Auth card
                    VStack(spacing: 22) {
                        // Sign in / Sign up toggle
                        HStack(spacing: 0) {
                            modeTab("Sign in", selected: mode == .login) { mode = .login }
                            modeTab("Sign up", selected: mode == .register) { mode = .register }
                        }
                        .background(Color(hex: "#f0ece6"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        // Input fields
                        VStack(spacing: 18) {
                            if mode == .register {
                                CPField(placeholder: "Your name", text: $vm.name)
                            }
                            CPField(placeholder: "Email", text: $vm.email, keyboardType: .emailAddress)
                            CPField(placeholder: "Password", text: $vm.password, isSecure: true)
                        }

                        // Error message
                        if let err = vm.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text(err)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.inter(11))
                            .foregroundColor(Color(hex: "#c0607a"))
                            .padding(12)
                            .background(Color(hex: "#c0607a").opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // Submit button
                        Button {
                            Task {
                                if mode == .login {
                                    await vm.login(appState: appState)
                                } else {
                                    await vm.register(appState: appState)
                                }
                            }
                        } label: {
                            Group {
                                if vm.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(mode == .login ? "Sign in" : "Create account")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(appState.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(vm.isLoading)
                    }
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#e8e4de"), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: "#006cd1").opacity(0.06), radius: 20, x: 0, y: 4)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 48)
                }
            }
        }
        .onChange(of: mode) { _ in vm.errorMessage = nil }
    }

    private func modeTab(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.inter(13))
                .fontWeight(selected ? .semibold : .regular)
                .foregroundColor(selected ? appState.accentColor : Color(hex: "#9a9490"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(3)
        }
    }
}

// MARK: – Reusable underline field

struct CPField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
        .padding(.bottom, 10)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#e8e4de")),
            alignment: .bottom
        )
    }
}
