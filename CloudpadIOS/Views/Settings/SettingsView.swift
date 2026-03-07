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
                            .font(.inter(36))
                            .frame(width: 52, height: 52)
                            .background(Color(hex: "#f0ece6"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.visibleName)
                                .font(.inter(17, weight: .semibold))
                                .foregroundColor(Color(hex: "#1a1714"))
                            Text(user.email)
                                .font(.inter(11))
                                .foregroundColor(Color(hex: "#9a9490"))
                            if user.plan != "free" {
                                Text(user.plan.capitalized)
                                    .font(.inter(10))
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

            // PRO upgrade (only shown on free plan)
            if appState.user?.plan == "free" {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upgrade to cloudpad PRO")
                                .font(.inter(15, weight: .bold))
                                .foregroundColor(Color(hex: "#1a1714"))
                            Text("Unlimited pads, sync, and more")
                                .font(.inter(12))
                                .foregroundColor(Color(hex: "#9a9490"))
                        }

                        HStack(spacing: 12) {
                            PricingCard(label: "Monthly",  price: "$2",  period: "/ month",  badge: nil)
                                .environmentObject(appState)
                            PricingCard(label: "Lifetime", price: "$99", period: "one-time", badge: "BEST VALUE")
                                .environmentObject(appState)
                        }

                        Text("Prices in USD · Subscriptions auto-renew · Cancel anytime")
                            .font(.inter(10))
                            .foregroundColor(Color(hex: "#c4bfb8"))
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.white)
                } header: {
                    Text("PRO")
                }
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
                            .font(.inter(11))
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

// MARK: – Pricing card

struct PricingCard: View {
    @EnvironmentObject var appState: AppState
    let label: String
    let price: String
    let period: String
    let badge: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Badge row (preserves height whether badge exists or not)
            Group {
                if let badge {
                    Text(badge)
                        .font(.inter(9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(appState.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Color.clear.frame(height: 21)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.inter(12, weight: .semibold))
                    .foregroundColor(Color(hex: "#9a9490"))
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(price)
                        .font(.inter(26, weight: .bold))
                        .foregroundColor(Color(hex: "#1a1714"))
                    Text(period)
                        .font(.inter(11))
                        .foregroundColor(Color(hex: "#9a9490"))
                }
            }

            Button {
                // StoreKit purchase – wired up in a future release
            } label: {
                Text("Upgrade")
                    .font(.inter(13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(appState.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color(hex: "#f7f4f0"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    badge != nil ? appState.accentColor.opacity(0.4) : Color(hex: "#e8e4de"),
                    lineWidth: 1
                )
        )
        .frame(maxWidth: .infinity)
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
