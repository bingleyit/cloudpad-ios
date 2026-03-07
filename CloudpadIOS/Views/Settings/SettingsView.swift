import SwiftUI

// MARK: – Settings content (used inside SettingsTab's NavigationStack)

struct SettingsContent: View {
    @EnvironmentObject var appState: AppState
    @State private var showThemePicker = false

    var body: some View {
        List {
            // Account section
            Section {
                if let user = appState.user {
                    HStack(spacing: 14) {
                        Text(user.avatar.isEmpty ? "🌸" : user.avatar)
                            .font(.system(size: 36))
                            .frame(width: 52, height: 52)
                            .background(Color(hex: "#f0ece6"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.visibleName)
                                .font(.headline)
                                .foregroundColor(Color(hex: "#1a1714"))
                            Text(user.email)
                                .font(.caption)
                                .foregroundColor(Color(hex: "#9a9490"))
                            if user.plan != "free" {
                                Text(user.plan.capitalized)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(appState.accentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(appState.accentColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            } header: {
                Text("Account")
            }

            // Appearance section
            Section {
                Button {
                    showThemePicker = true
                } label: {
                    HStack {
                        Label("Accent colour", systemImage: "paintpalette")
                            .foregroundColor(Color(hex: "#1a1714"))
                        Spacer()
                        Circle()
                            .fill(appState.accentColor)
                            .frame(width: 22, height: 22)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#c4bfb8"))
                    }
                }
            } header: {
                Text("Appearance")
            }

            // Sign out
            Section {
                Button(role: .destructive) {
                    appState.logout()
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showThemePicker) {
            ThemePickerView()
                .environmentObject(appState)
        }
    }
}

// MARK: – Legacy wrapper kept for any future sheet usage

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        SettingsContent()
            .environmentObject(appState)
    }
}
