import SwiftUI

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

    var activePadKey: String {
        mode == .days ? dayKey(currentDate) : selectedPadKey
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
                } else {
                    ListsTabBar(selectedPadKey: $selectedPadKey)
                        .environmentObject(appState)
                        .environmentObject(notesVM)
                }

                Divider().foregroundColor(Color(hex: "#e8e4de"))

                PadContentView(padKey: activePadKey, mode: mode)
                    .environmentObject(appState)
                    .environmentObject(notesVM)
                    .id(activePadKey)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

            // "cloudpad" cursive wordmark — Caveat matches the web app's branding
            Text("cloudpad")
                .font(.caveat(30, weight: .bold))
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
            .padding(.bottom, 14)

            // ── Text input with accent underline ─────────────────────
            ZStack(alignment: .topLeading) {
                if taskText.isEmpty {
                    Text("What needs to get done? (try 'buy milk tomorrow' or\n'meeting next friday')")
                        .font(.inter(17))
                        .foregroundColor(Color(hex: "#c4bfb8"))
                        .padding(.horizontal, 20)
                        .padding(.top, 2)
                        .allowsHitTesting(false)
                }
                TextField("", text: $taskText, axis: .vertical)
                    .font(.inter(17))
                    .foregroundColor(Color(hex: "#1a1714"))
                    .focused($focused)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 52, alignment: .top)
            }

            Rectangle()
                .frame(height: 1.5)
                .foregroundColor(appState.accentColor)
                .padding(.horizontal, 20)

            Spacer().frame(height: 20)

            // ── Type chips — row 1 ───────────────────────────────────
            chipRow(row1)
            Spacer().frame(height: 10)
            chipRow(row2)

            Spacer().frame(height: 18)

            // ── Date picker + Add Task button ────────────────────────
            HStack(spacing: 10) {
                // Date dropdown styled like the web's <select>
                Menu {
                    ForEach(dateOptions(), id: \.date) { opt in
                        Button(opt.label) { selectedDate = opt.date }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(dateMenuLabel(selectedDate))
                            .font(.inter(14))
                            .foregroundColor(Color(hex: "#1a1714"))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.inter(11))
                            .foregroundColor(Color(hex: "#9a9490"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#e8e4de"), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity)

                Button {
                    let trimmed = taskText.trimmingCharacters(in: .whitespaces)
                    guard let token = appState.token, !trimmed.isEmpty else { return }
                    notesVM.addTask(padKey: padKey, text: trimmed, token: token)
                    isPresented = false
                } label: {
                    Text("Add Task")
                        .font(.inter(15, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(appState.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(taskText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)

            // ── Tip text ─────────────────────────────────────────────
            Text("tip: type \"tomorrow\", \"next monday\", or a date to auto-schedule")
                .font(.inter(11))
                .foregroundColor(Color(hex: "#9a9490"))
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Spacer()
        }
        .background(Color.white)
        .presentationDetents([.height(420), .large])
        .onAppear { focused = true }
    }

    // MARK: – Chip row helper

    private func chipRow(_ types: [QuickAddType]) -> some View {
        HStack(spacing: 8) {
            ForEach(types, id: \.rawValue) { type in
                let selected = selectedType == type
                Button { selectedType = type } label: {
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
        if cal.isDateInToday(date)    { return "Today · \(fmt.string(from: date))" }
        if cal.isDateInTomorrow(date) { return "Tomorrow · \(fmt.string(from: date))" }
        return fmt.string(from: date)
    }
}
