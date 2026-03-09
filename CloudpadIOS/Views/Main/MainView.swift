import SwiftUI
import LocalAuthentication

// MARK: – Mode

enum AppMode { case days, lists }

// MARK: – Root

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var notesVM = NotesViewModel()
    @Environment(\.scenePhase) private var scenePhase

    @State private var mode: AppMode = .lists
    @State private var selectedPadKey: String = Config.specialPads.first?.key ?? "personal"
    @State private var currentDate: Date = Date()
    @State private var showPadsSheet = false
    @State private var showQuickAdd = false
    @State private var showSettings = false
    @State private var codesUnlocked = false

    var activePadKey: String {
        mode == .days ? dayKey(currentDate) : selectedPadKey
    }

    /// True when the selected pad is in extendedPads but NOT in specialPads (e.g. travel, recipes, codes, projects)
    var isExtendedOnlyPad: Bool {
        guard mode == .lists else { return false }
        let inExtended = Config.extendedPads.contains(where: { $0.key == selectedPadKey })
        let inSpecial  = Config.specialPads.contains(where: { $0.key == selectedPadKey })
        return inExtended && !inSpecial
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                AppHeader(showPadsSheet: $showPadsSheet, showSettings: $showSettings)
                    .environmentObject(appState)

                if mode == .days {
                    DaysSubHeader(currentDate: $currentDate)
                        .environmentObject(appState)
                } else if isExtendedOnlyPad,
                          let extPad = Config.extendedPads.first(where: { $0.key == selectedPadKey }) {
                    ExtendedPadSubHeader(pad: extPad) {
                        selectedPadKey = Config.specialPads.first?.key ?? "personal"
                    }
                    .environmentObject(appState)
                    .environmentObject(notesVM)
                } else {
                    ListsTabBar(selectedPadKey: $selectedPadKey)
                        .environmentObject(appState)
                        .environmentObject(notesVM)
                }

                Divider().foregroundColor(Color(hex: "#e8e4de"))

                // Codes pad gate: biometric/passcode required
                Group {
                    if activePadKey == "codes" && !codesUnlocked {
                        CodesPadGate(onUnlock: { codesUnlocked = true })
                            .environmentObject(appState)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        PadContentView(padKey: activePadKey, mode: mode)
                            .environmentObject(appState)
                            .environmentObject(notesVM)
                            .id(activePadKey)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                    // ── Swipe left/right to navigate ──────────────────
                    .gesture(
                        DragGesture(minimumDistance: 40, coordinateSpace: .local)
                            .onEnded { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                guard abs(dx) > abs(dy) else { return }
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    if mode == .days {
                                        let delta = dx < 0 ? 1 : -1
                                        currentDate = Calendar.current.date(
                                            byAdding: .day, value: delta, to: currentDate)!
                                    } else if isExtendedOnlyPad {
                                        // Swipe between extended pads
                                        let pads = Config.extendedPads
                                        if let idx = pads.firstIndex(where: { $0.key == selectedPadKey }) {
                                            let next = dx < 0 ? idx + 1 : idx - 1
                                            if pads.indices.contains(next) {
                                                selectedPadKey = pads[next].key
                                            } else if dx > 0 {
                                                // Swipe right from first extended pad → back to special pads
                                                selectedPadKey = Config.specialPads.first?.key ?? "personal"
                                            }
                                        }
                                    } else {
                                        let pads = Config.specialPads
                                        if let idx = pads.firstIndex(where: { $0.key == selectedPadKey }) {
                                            let next = dx < 0 ? idx + 1 : idx - 1
                                            if pads.indices.contains(next) {
                                                selectedPadKey = pads[next].key
                                            }
                                        }
                                    }
                                }
                            }
                    )

                BottomModeToggle(mode: $mode)
                    .environmentObject(appState)
            }

            // Floating + button
            Button { showQuickAdd = true } label: {
                Image(systemName: "plus")
                    .font(.inter(22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(appState.accentColor)
                    .clipShape(Circle())
                    .shadow(color: appState.accentColor.opacity(0.35), radius: 8, x: 0, y: 3)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 76)
        }
        .sheet(isPresented: $showPadsSheet) {
            PadsGridSheet(selectedPadKey: $selectedPadKey, mode: $mode, isPresented: $showPadsSheet)
                .environmentObject(appState)
                .environmentObject(notesVM)
        }
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(padKey: activePadKey, isPresented: $showQuickAdd)
                .environmentObject(appState)
                .environmentObject(notesVM)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsContent().environmentObject(appState) }
        }
        .task {
            await appState.syncFromServer()
            guard let token = appState.token else { return }
            await notesVM.loadAll(token: token)
        }
        // Re-sync theme + tasks whenever the app comes back to the foreground
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await appState.syncFromServer() }
            // Re-lock codes when app goes to background
            if phase == .background { codesUnlocked = false }
        }
        // Refresh individual pad data when switching pads
        .onChange(of: selectedPadKey) { newKey in
            guard let token = appState.token else { return }
            Task { await notesVM.loadPad(padKey: newKey, token: token) }
            // Re-lock codes whenever we leave it (navigation away)
            if newKey != "codes" { codesUnlocked = false }
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
                    .font(.inter(18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            // "cloudpad" cursive wordmark — Caveat-Bold matches the web app's branding
            // Extra padding(.top, 6) compensates for Caveat's tall ascenders
            Text("cloudpad")
                .font(.caveat(32, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 6)
                .fixedSize()

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
                .font(.inter(20))
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
                    .font(.inter(12))
                    .foregroundColor(Color(hex: "#9a9490"))
                Text(dayLabel)
                    .font(.inter(17, weight: .bold))
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
                .font(.inter(15, weight: .semibold))
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
                        .font(.inter(12, weight: .semibold))
                        .foregroundColor(isSelected ? appState.accentColor : Color(hex: "#9a9490"))
                    if count > 0 {
                        Text("\(count)")
                            .font(.inter(11, weight: .bold))
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

// MARK: – Extended pad sub-header (travel, recipes, codes, projects)

struct ExtendedPadSubHeader: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notesVM: NotesViewModel
    let pad: (key: String, label: String, icon: String)
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // ← back to Lists
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.inter(13, weight: .semibold))
                    Text("LISTS")
                        .font(.inter(12, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#9a9490"))
            }

            Spacer()

            // Pad icon + name + task count badge
            HStack(spacing: 8) {
                Image(systemName: pad.icon)
                    .font(.inter(15, weight: .medium))
                    .foregroundColor(appState.accentColor)
                Text(pad.label.uppercased())
                    .font(.inter(14, weight: .bold))
                    .foregroundColor(Color(hex: "#1a1714"))
                let count = notesVM.tasks(for: pad.key).filter { !$0.isDivider && !$0.done }.count
                if count > 0 {
                    Text("\(count)")
                        .font(.inter(10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(appState.accentColor)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Balance spacer (invisible)
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.inter(13, weight: .semibold))
                Text("LISTS")
                    .font(.inter(12, weight: .semibold))
            }
            .opacity(0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(height: 46)
        .background(Color.white)
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
                    .font(.inter(14, weight: .medium))
                Text(label)
                    .font(.inter(13, weight: .semibold))
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
                    .font(.inter(12, weight: .bold))
                    .foregroundColor(Color(hex: "#9a9490"))
                    .tracking(1.2)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.inter(14, weight: .semibold))
                        .foregroundColor(Color(hex: "#9a9490"))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: "#f0ece6"))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)

            // 3-column grid of the extended pads
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 20) {
                ForEach(Config.extendedPads, id: \.key) { pad in
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
        .presentationDetents([.height(280)])
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
                    .font(.inter(22, weight: .medium))
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
                    .font(.inter(10, weight: .semibold))
                    .foregroundColor(isSelected ? appState.accentColor : Color(hex: "#9a9490"))
                    .tracking(0.5)
            }
        }
    }
}

// MARK: – Quick add bottom sheet

enum QuickAddType: String, CaseIterable {
    case task, snap, meal, reminder, event, note, link, section

    var emoji: String {
        switch self {
        case .task:     return ""
        case .snap:     return "⚡"
        case .meal:     return "🥙"
        case .reminder: return "⏰"
        case .event:    return "📅"
        case .note:     return "📝"
        case .link:     return "🔗"
        case .section:  return "§"
        }
    }

    var label: String { rawValue }
}

struct QuickAddSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notesVM: NotesViewModel
    let padKey: String
    @Binding var isPresented: Bool

    @State private var taskText = ""
    @State private var selectedType: QuickAddType = .task
    @State private var selectedDate: Date = Date()
    @FocusState private var focused: Bool

    // Chips are split into two rows matching the web layout
    private let row1: [QuickAddType] = [.task, .snap, .meal, .reminder, .event]
    private let row2: [QuickAddType] = [.note, .link, .section]

    private var placeholder: String {
        switch selectedType {
        case .task:     return "What needs to get done?"
        case .snap:     return "Quick capture..."
        case .meal:     return "What's the meal?"
        case .reminder: return "Remind me to..."
        case .event:    return "Event name or details..."
        case .note:     return "Write a note..."
        case .link:     return "Paste a URL or link..."
        case .section:  return "Section heading..."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle
            Capsule()
                .frame(width: 36, height: 4)
                .foregroundColor(Color(hex: "#e8e4de"))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            // ── Header ──────────────────────────────────────────────
            HStack(spacing: 6) {
                Text("✦")
                    .font(.inter(13))
                    .foregroundColor(appState.accentColor)
                Text("QUICK ADD")
                    .font(.inter(12, weight: .bold))
                    .foregroundColor(Color(hex: "#9a9490"))
                    .tracking(1.2)
                Spacer()
                Button { isPresented = false } label: {
                    Text("×")
                        .font(.inter(22, weight: .light))
                        .foregroundColor(Color(hex: "#9a9490"))
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // ── Type chips — row 1 ───────────────────────────────────
            chipRow(row1)
            Spacer().frame(height: 8)
            chipRow(row2)

            Spacer().frame(height: 14)

            // ── Text input with accent underline ─────────────────────
            ZStack(alignment: .topLeading) {
                if taskText.isEmpty {
                    Text(placeholder)
                        .font(.inter(17))
                        .foregroundColor(Color(hex: "#c4bfb8"))
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                        .allowsHitTesting(false)
                }
                TextField("", text: $taskText, axis: .vertical)
                    .font(selectedType == .link ? .inter(15) : .inter(17))
                    .foregroundColor(Color(hex: "#1a1714"))
                    .keyboardType(selectedType == .link ? .URL : .default)
                    .textContentType(selectedType == .link ? .URL : .none)
                    .focused($focused)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 48, alignment: .top)
                    // Date picker + Add Task in keyboard toolbar (avoids double-animation)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Menu {
                                ForEach(dateOptions(), id: \.date) { opt in
                                    Button(opt.label) { selectedDate = opt.date }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.inter(14))
                                    Text(dateMenuLabel(selectedDate))
                                        .font(.inter(13))
                                }
                                .foregroundColor(Color(hex: "#9a9490"))
                            }

                            Spacer()

                            Button {
                                addItem()
                            } label: {
                                Text(selectedType == .snap ? "Snap" : selectedType == .section ? "Add Section" : "Add")
                                    .font(.inter(14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        taskText.trimmingCharacters(in: .whitespaces).isEmpty
                                            ? appState.accentColor.opacity(0.4)
                                            : appState.accentColor
                                    )
                                    .clipShape(Capsule())
                            }
                            .disabled(taskText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
            }

            Rectangle()
                .frame(height: 1.5)
                .foregroundColor(appState.accentColor)
                .padding(.horizontal, 20)

            // ── Tip text ─────────────────────────────────────────────
            Text(tipText)
                .font(.inter(11))
                .foregroundColor(Color(hex: "#9a9490"))
                .padding(.horizontal, 20)
                .padding(.top, 10)

            Spacer()
        }
        .background(Color.white)
        // Fixed height avoids the two-step animation; Add button is in keyboard toolbar
        .presentationDetents([.height(360), .large])
        // Keyboard opens within the same animation frame as the sheet
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focused = true
            }
        }
        // snap: auto-submit when user finishes typing (presses return)
        .onChange(of: taskText) { text in
            if selectedType == .snap && text.last == "\n" {
                taskText = String(text.dropLast())
                addItem()
            }
        }
    }

    private var tipText: String {
        switch selectedType {
        case .section: return "Creates a section divider in your list"
        case .snap:    return "Snap captures instantly — just type and press return"
        case .link:    return "Paste a full URL to save a link"
        default:       return "Tip: use --- prefix to add a divider section"
        }
    }

    private func addItem() {
        let trimmed = taskText.trimmingCharacters(in: .whitespaces)
        guard let token = appState.token, !trimmed.isEmpty else { return }
        notesVM.addTask(padKey: padKey, text: trimmed, type: selectedType, token: token)
        isPresented = false
    }

    // MARK: – Chip row helper

    private func chipRow(_ types: [QuickAddType]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(types, id: \.rawValue) { type in
                    let selected = selectedType == type
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedType = type }
                    } label: {
                        HStack(spacing: type.emoji.isEmpty ? 0 : 4) {
                            if !type.emoji.isEmpty {
                                Text(type.emoji).font(.inter(13))
                            }
                            Text(type.label)
                                .font(.inter(13, weight: selected ? .semibold : .regular))
                        }
                        .foregroundColor(selected ? .white : Color(hex: "#1a1714"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selected ? appState.accentColor : Color.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                selected ? appState.accentColor : Color(hex: "#e8e4de"),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: – Date helpers

    private struct DateOption: Hashable { let date: Date; let label: String }

    private func dateOptions() -> [DateOption] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var opts: [DateOption] = []
        let fmt = DateFormatter(); fmt.dateFormat = "EEEE"
        for d in 0..<8 {
            let date = cal.date(byAdding: .day, value: d, to: today)!
            let dayName = fmt.string(from: date)
            let prefix = d == 0 ? "Today" : d == 1 ? "Tomorrow" : dayName
            opts.append(DateOption(date: date, label: prefix))
        }
        return opts
    }

    private func dateMenuLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "EEEE"
        if cal.isDateInToday(date)    { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return fmt.string(from: date)
    }
}

// MARK: – Codes pad biometric gate

struct CodesPadGate: View {
    @EnvironmentObject var appState: AppState
    let onUnlock: () -> Void
    @State private var authError: String?
    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(appState.accentColor.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "lock.fill")
                    .font(.inter(38, weight: .medium))
                    .foregroundColor(appState.accentColor)
            }

            VStack(spacing: 8) {
                Text("Codes Locked")
                    .font(.inter(22, weight: .bold))
                    .foregroundColor(Color(hex: "#1a1714"))
                Text("Authenticate to view your saved codes")
                    .font(.inter(14))
                    .foregroundColor(Color(hex: "#9a9490"))
                    .multilineTextAlignment(.center)
            }

            if let error = authError {
                Text(error)
                    .font(.inter(12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task { await authenticate() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: biometricIcon)
                        .font(.inter(16, weight: .medium))
                    Text(biometricLabel)
                        .font(.inter(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isAuthenticating ? appState.accentColor.opacity(0.5) : appState.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
            .disabled(isAuthenticating)

            Spacer()
        }
        .background(Color.white)
        .task { await authenticate() }
    }

    private var biometricIcon: String {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            return "lock.open.fill"
        }
        return ctx.biometryType == .faceID ? "faceid" : "touchid"
    }

    private var biometricLabel: String {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            return "Unlock with Passcode"
        }
        return ctx.biometryType == .faceID ? "Unlock with Face ID" : "Unlock with Touch ID"
    }

    private func authenticate() async {
        isAuthenticating = true
        authError = nil
        let context = LAContext()
        var error: NSError?
        // .deviceOwnerAuthentication falls back to passcode if no biometrics
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Simulator or device with no auth configured — just unlock
            onUnlock()
            isAuthenticating = false
            return
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your Codes pad"
            )
            if success { onUnlock() }
        } catch {
            let laError = error as? LAError
            // User tapped cancel — show a prompt to try again
            if laError?.code != .userCancel {
                authError = error.localizedDescription
            }
        }
        isAuthenticating = false
    }
}
