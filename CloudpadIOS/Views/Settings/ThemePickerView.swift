import SwiftUI

struct ThemePickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHex: String = ""
    @State private var customHex: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Preview
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: selectedHex.isEmpty ? (appState.user?.theme ?? "#7c5cbf") : selectedHex))
                            .frame(width: 44, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accent colour")
                                .font(.inter(17, weight: .semibold))
                            Text(selectedHex.isEmpty ? (appState.user?.theme ?? "#7c5cbf") : selectedHex)
                                .font(.inter(11))
                                .foregroundColor(Color(hex: "#9a9490"))
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(hex: "#f7f4f0"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Preset swatches
                    Text("Presets")
                        .font(.inter(13))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#9a9490"))

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(Config.accentPresets, id: \.hex) { preset in
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(Color(hex: preset.hex))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: "#1a1714"), lineWidth: isSelected(preset.hex) ? 2.5 : 0)
                                            .padding(3)
                                    )
                                    .onTapGesture { selectedHex = preset.hex }

                                Text(preset.name)
                                    .font(.inter(10))
                                    .foregroundColor(Color(hex: "#9a9490"))
                            }
                        }
                    }

                    // Custom hex
                    Text("Custom")
                        .font(.inter(13))
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#9a9490"))

                    HStack {
                        Text("#")
                            .foregroundColor(Color(hex: "#9a9490"))
                        TextField("7c5cbf", text: $customHex)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: customHex) { val in
                                let clean = val.replacingOccurrences(of: "#", with: "")
                                if clean.count == 6, let _ = UInt64(clean, radix: 16) {
                                    selectedHex = "#\(clean)"
                                }
                            }
                    }
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#e8e4de"), lineWidth: 1)
                    )

                    if let err = errorMessage {
                        Text(err)
                            .font(.inter(11))
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose colour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Apply")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(selectedHex.isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            selectedHex = appState.resolvedAccentHex
        }
    }

    private func isSelected(_ hex: String) -> Bool {
        selectedHex.lowercased() == hex.lowercased()
    }

    private func save() async {
        guard let token = appState.token else { return }
        isSaving = true
        do {
            var body = APIService.PreferencesBody()
            body.theme = selectedHex
            let updated = try await APIService.shared.updatePreferences(body, token: token)
            appState.updateUser(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
