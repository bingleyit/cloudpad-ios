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
                    VStack(spacing: 6) {
                        Text("☁️")
                            .font(.system(size: 52))
                        Text("cloudpad")
                            .font(.custom("DM Sans", size: 28))
                            .fontWeight(.semibold)
                            .foregroundColor(appState.accentColor)
                    }
                    .padding(.top, 72)
                    .padding(.bottom, 36)

                    // Card
                    VStack(spacing: 20) {
                        // Mode toggle
                        HStack(spacing: 0) {
                            modeTab("Sign in", selected: mode == .login) { mode = .login }
                            modeTab("Sign up", selected: mode == .register) { mode = .register }
                        }
                        .background(Color(hex: "#f0ece6"))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Fields
                        VStack(spacing: 14) {
                            if mode == .register {
                                CPField(placeholder: "Your name", text: $vm.name)
                            }
                            CPField(placeholder: "Email", text: $vm.email, keyboardType: .emailAddress)
                            CPField(placeholder: "Password", text: $vm.password, isSecure: true)
                        }

                        // Error
                        if let err = vm.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Submit
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
                            .padding(.vertical, 14)
                            .background(appState.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(vm.isLoading)
                    }
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 4)
                    .padding(.horizontal, 24)
                }
            }
        }
        .onChange(of: mode) { _ in vm.errorMessage = nil }
    }

    private func modeTab(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(selected ? .semibold : .regular)
                .foregroundColor(selected ? appState.accentColor : Color(hex: "#9a9490"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .padding(3)
        }
    }
}

// Reusable underline text field
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
        .padding(.bottom, 8)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#e8e4de")),
            alignment: .bottom
        )
    }
}
