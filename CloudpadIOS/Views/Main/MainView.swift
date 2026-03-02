import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var notesVM = NotesViewModel()
    @State private var selectedPadKey: String = todayKey()
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedPadKey: $selectedPadKey)
                .environmentObject(notesVM)
        } detail: {
            PadView(padKey: selectedPadKey)
                .environmentObject(notesVM)
                .id(selectedPadKey)   // Force re-init when pad changes
        }
        .tint(appState.accentColor)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .task {
            guard let token = appState.token else { return }
            // Refresh user profile from server (picks up any changes made on web)
            if let freshUser = try? await APIService.shared.fetchMe(token: token) {
                appState.updateUser(freshUser)
            }
            await notesVM.loadAll(token: token)
        }
    }

    static func todayKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
}

// MARK: – Sidebar

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notesVM: NotesViewModel
    @Binding var selectedPadKey: String
    @State private var weekOffset = 0

    var weekDays: [Date] {
        let cal = Calendar.current
        let today = Date()
        // Start on Monday of the offset week
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        comps.weekday = 2  // Monday
        let monday = cal.date(from: comps)!
        let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: monday)!
        return (0..<5).compactMap { cal.date(byAdding: .day, value: $0, to: base) }
    }

    var body: some View {
        List(selection: $selectedPadKey) {
            // Week header + nav
            Section {
                HStack {
                    Button { weekOffset -= 1 } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(weekLabel)
                        .font(.caption)
                        .foregroundColor(Color(hex: "#9a9490"))
                        .onTapGesture { weekOffset = 0 }

                    Spacer()

                    Button { weekOffset += 1 } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Color.clear)

                ForEach(weekDays, id: \.self) { date in
                    let key = dayKey(date)
                    DaySidebarRow(date: date, padKey: key, isSelected: selectedPadKey == key)
                        .tag(key)
                }
            }

            // Special pads
            Section("Pads") {
                ForEach(Config.specialPads, id: \.key) { pad in
                    Label(pad.label, systemImage: pad.icon)
                        .tag(pad.key)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(
            appState.user.flatMap { $0.workspaceName.isEmpty ? nil : $0.workspaceName } ?? "cloudpad"
        )
    }

    private var weekLabel: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        let fmtYear = DateFormatter()
        fmtYear.dateFormat = "d MMM yyyy"
        return "\(fmt.string(from: first)) – \(fmtYear.string(from: last))"
    }

    private func dayKey(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}

struct DaySidebarRow: View {
    let date: Date
    let padKey: String
    let isSelected: Bool

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(dayName)
                    .font(.subheadline)
                    .fontWeight(isToday ? .semibold : .regular)
                Text(dateLabel)
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#9a9490"))
            }
            Spacer()
            if isToday {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var dayName: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        return fmt.string(from: date)
    }

    private var dateLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        return fmt.string(from: date)
    }
}
