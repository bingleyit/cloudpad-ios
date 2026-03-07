import SwiftUI

// MARK: – Mode

enum AppMode { case days, lists }

// MARK: – Root

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var notesVM = NotesViewModel()

    @State private var mode: AppMode = .lists
    @State private var selectedPadKey: String = Config.specialPads.first?.key ?? "personal"
    @State private var currentDate: Date = Date()
    @State private var showPadsSheet = false
    @State private var showQuickAdd = false
    @State private var showSettings = false

    var activePadKey: String {
        mode == .days ? dayKey(currentDate) : selectedPadKey
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Blue header
                AppHeader(showPadsSheet: $showPadsSheet, showSettings: $showSettings)
                    .environmentObject(appState)

                // Mode-specific sub-header
                if mode == .days {
                    DaysSubHeader(currentDate: $currentDate)
                        .environmentObject(appState)
                } else {
                    ListsTabBar(selectedPadKey: $selectedPadKey)
                        .environmentObject(appState)
                        .environmentObject(notesVM)
                }

                Divider().foregroundColor(Color(hex: "#e8e4de"))

                // Task content
                PadContentView(padKey: activePadKey, mode: mode)
                    .environmentObject(appState)
                    .environmentObject(notesVM)
                    .id(activePadKey)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom DAYS / LISTS toggle
                BottomModeToggle(mode: $mode)
                    .environmentObject(appState)
            }

            // Floating + button
            Button { showQuickAdd = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(appState.accentColor)
                    .clipShape(Circle())
                    .shadow(color: appState.accentColor.opacity(0.35), radius: 8, x: 0, y: 3)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 76) // sits above the bottom toggle bar
        }
        .sheet(isPresented: $showPadsSheet) {
            PadsGridSheet(
                selectedPadKey: $selectedPadKey,
                mode: $mode,
                isPresented: $showPadsSheet
            )
            .environmentObject(appState)
            .environmentObject(notesVM)
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(padKey: activePadKey, isPresented: $showQuickAdd)
                .environmentObject(appState)
                .environmentObject(notesVM)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsContent().environmentObject(appState)
            }
        }
        .task {
            guard let token = appState.token else { return }
            if let freshUser = try? await APIService.shared.fetchMe(token: token) {
                appState.updateUser(freshUser)
            }
            await notesVM.loadAll(token: token)
        }
    }

    private func dayKey(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}

// MARK: – Blue header bar

struct AppHeader: View {
    @EnvironmentObject var appState: AppState
    @Binding var showPadsSheet: Bool
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Hamburger → pads sheet
            Button { showPadsSheet = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            // "cloudpad" cursive wordmark
            Text("cloudpad")
                .font(.custom("BradleyHandITCTT-Bold", size: 26))
                .foregroundColor(.white)

            Spacer()

            // Avatar → settings
            Button { showSettings = true } label: {
                UserAvatarView(user: appState.user)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            appState.accentColor
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: – Avatar

struct UserAvatarView: View {
    let user: User?

    var body: some View {
        Group {
            if let urlStr = user?.profileImage, !urlStr.isEmpty, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image { img.resizable().scaledToFill() }
                    else { fallback }
                }
            } else {
                fallback
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.2))
            Text(user?.avatar.isEmpty == false ? user!.avatar : "🌸")
                .font(.system(size: 20))
        }
    }
}

// MARK: – Days sub-header (date navigation)

struct DaysSubHeader: View {
    @EnvironmentObject var appState: AppState
    @Binding var currentDate: Date

    var body: some View {
        HStack {
            navArrow("chevron.left") {
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate)!
            }

            Spacer()

            VStack(spacing: 2) {
                Text(dateLabel)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#9a9490"))
                Text(dayLabel)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(appState.accentColor)
            }
            .onTapGesture { currentDate = Date() } // tap centre → today

            Spacer()

            navArrow("chevron.right") {
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "#f7f4f0"))
    }

    private func navArrow(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "#9a9490"))
                .frame(width: 36, height: 36)
                .background(Color.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(hex: "#e8e4de"), lineWidth: 1))
        }
    }

    private var dateLabel: String {
        let fmt = DateFormatter(); fmt.dateFormat = "d MMM yyyy"
        return fmt.string(from: currentDate).uppercased()
    }

    private var dayLabel: String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEEE"
        return fmt.string(from: currentDate).uppercased()
    }
}

// MARK: – Lists horizontal tab bar

struct ListsTabBar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notesVM: NotesViewModel
    @Binding var selectedPadKey: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Config.specialPads, id: \.key) { pad in
                    let count = notesVM.tasks(for: pad.key).filter { !$0.isDivider && !$0.done }.count
                    PadTabButton(
                        label: pad.label,
                        count: count,
                        isSelected: selectedPadKey == pad.key
                    ) {
                        selectedPadKey = pad.key
                    }
                    .environmentObject(appState)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 46)
        .background(Color.white)
    }
}

struct PadTabButton: View {
    @EnvironmentObject var appState: AppState
    let label: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text(label.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? appState.accentColor : Color(hex: "#9a9490"))
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isSelected ? appState.accentColor : Color(hex: "#9a9490"))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

                // Underline for active tab
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? appState.accentColor : Color.clear)
            }
        }
    }
}

// MARK: – Bottom DAYS / LISTS toggle

struct BottomModeToggle: View {
    @EnvironmentObject var appState: AppState
    @Binding var mode: AppMode

    var body: some View {
        HStack(spacing: 0) {
            modeButton("calendar", "DAYS", mode == .days) { mode = .days }
            modeButton("list.bullet", "LISTS", mode == .lists) { mode = .lists }
        }
        .padding(4)
        .background(Color(hex: "#f0ece6"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -2)
        )
    }

    private func modeButton(_ icon: String, _ label: String, _ active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(active ? .white : Color(hex: "#9a9490"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(active ? appState.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: – Pads grid bottom sheet

struct PadsGridSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notesVM: NotesViewModel
    @Binding var selectedPadKey: String
    @Binding var mode: AppMode
    @Binding var isPresented: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle
            Capsule()
                .frame(width: 36, height: 4)
                .foregroundColor(Color(hex: "#e8e4de"))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            HStack {
                Text("PADS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#9a9490"))
                    .tracking(1.2)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#9a9490"))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "#f0ece6"))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)

            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(Config.specialPads, id: \.key) { pad in
                    let isSelected = selectedPadKey == pad.key && mode == .lists
                    PadGridCell(pad: pad, isSelected: isSelected) {
                        selectedPadKey = pad.key
                        mode = .lists
                        isPresented = false
                    }
                    .environmentObject(appState)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.white)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}

struct PadGridCell: View {
    @EnvironmentObject var appState: AppState
    let pad: (key: String, label: String, icon: String)
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: pad.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color(hex: "#9a9490"))
                    .frame(width: 62, height: 62)
                    .background(isSelected ? appState.accentColor : Color(hex: "#f7f4f0"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? appState.accentColor : Color(hex: "#e8e4de"),
                                lineWidth: 1
                            )
                    )

                Text(pad.label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? appState.accentColor : Color(hex: "#9a9490"))
                    .tracking(0.5)
            }
        }
    }
}

// MARK: – Quick add bottom sheet

struct QuickAddSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notesVM: NotesViewModel
    let padKey: String
    @Binding var isPresented: Bool

    @State private var taskText = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle
            Capsule()
                .frame(width: 36, height: 4)
                .foregroundColor(Color(hex: "#e8e4de"))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            // Header
            HStack {
                Text("✦")
                    .foregroundColor(appState.accentColor)
                Text("QUICK ADD")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#9a9490"))
                    .tracking(1.2)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#9a9490"))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "#f0ece6"))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)

            // Text input
            TextField(
                "What needs to get done?",
                text: $taskText,
                axis: .vertical
            )
            .font(.system(size: 17))
            .foregroundColor(Color(hex: "#1a1714"))
            .focused($focused)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Accent underline
            Rectangle()
                .frame(height: 1.5)
                .foregroundColor(appState.accentColor)
                .padding(.horizontal, 20)

            Spacer().frame(height: 28)

            // Add button row
            HStack {
                Spacer()
                Button {
                    let trimmed = taskText.trimmingCharacters(in: .whitespaces)
                    guard let token = appState.token, !trimmed.isEmpty else { return }
                    notesVM.addTask(padKey: padKey, text: trimmed, token: token)
                    isPresented = false
                } label: {
                    Text("Add Task")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(appState.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(taskText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color.white)
        .presentationDetents([.medium, .large])
        .onAppear { focused = true }
    }
}
