import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showThemePicker = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List {
                // Profile
                Section("Account") {
                    if let user = appState.user {
                        HStack(spacing: 14) {
                            Text(user.avatar.isEmpty ? "🌸" : user.avatar)
                                .font(.system(size: 36))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.visibleName)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#9a9490"))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Theme
                Section("Appearance") {
                    Button {
                        showThemePicker = true
                    } label: {
                        HStack {
                            Text("Accent colour")
                                .foregroundColor(.primary)
                            Spacer()
                            Circle()
                                .fill(appState.accentColor)
                                .frame(width: 22, height: 22)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#c4bfb8"))
                        }
                    }
                }

                // Sign out
                Section {
                    Button(role: .destructive) {
                        appState.logout()
                        dismiss()
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showThemePicker) {
                ThemePickerView()
                    .environmentObject(appState)
            }
        }
    }
}
