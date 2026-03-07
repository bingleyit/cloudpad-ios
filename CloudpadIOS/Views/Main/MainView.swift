import SwiftUI

// MARK: – Root tab layout

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var notesVM = NotesViewModel()

    var body: some View {
        TabView {
            TodayTab()
                .environmentObject(appState)
                .environmentObject(notesVM)
                .tabItem { Label("Today", systemImage: "calendar") }

            BrowseTab()
                .environmentObject(appState)
                .environmentObject(notesVM)
                .tabItem { Label("Pads", systemImage: "square.stack") }

            SettingsTab()
                .environmentObject(appState)
                .tabItem { Label("Settings", systemImage: "person.circle") }
        }
        .tint(appState.accentColor)
        .task {
            guard let token = appState.token else { return }
            if let freshUser = try? await APIService.shared.fetchMe(token: token) {
                appState.updateUser(freshUser)
            }
            await notesVM.loadAll(token: token)
        }
    }
}

// MARK: – Today tab

struct TodayTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notesVM: NotesViewModel

    var body: some View {
        NavigationStack {
            PadView(padKey: todayKey)
                .environmentObject(notesVM)
        }
    }

    private var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
}

// MARK: – Browse tab

struct BrowseTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notesVM: NotesViewModel
    @State private var weekOffset = 0

    var weekDays: [Date] {
        let cal = Calendar.current
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        comps.weekday = 2 // Monday
        let monday = cal.date(from: comps)!
        let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: monday)!
        return (0..<5).compactMap { cal.date(byAdding: .day, value: $0, to: base) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Week navigator
                    WeekNavigator(weekOffset: $weekOffset, weekDays: weekDays)

                    // Daily pads
                    VStack(spacing: 1) {
                        ForEach(weekDays, id: \.self) { date in
                            let key = dayKey(date)
                            NavigationLink {
                                PadView(padKey: key)
                                    .environmentObject(notesVM)
                            } label: {
                                DayCard(date: date, padKey: key)
                                    .environmentObject(notesVM)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "#e8e4de"), lineWidth: 1)
                    )

                    // Special pads header
                    Text("Pads")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#9a9490"))
                        .textCase(.uppercase)
                        .tracking(0.5)

                    // Special pads
                    VStack(spacing: 1) {
                        ForEach(Config.specialPads, id: \.key) { pad in
                            NavigationLink {
                                PadView(padKey: pad.key)
                                    .environmentObject(notesVM)
                            } label: {
                                SpecialPadCard(pad: pad, notesVM: notesVM)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "#e8e4de"), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(hex: "#f7f4f0"))
            .navigationTitle(workspaceTitle)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var workspaceTitle: String {
        appState.user.flatMap { $0.workspaceName.isEmpty ? nil : $0.workspaceName } ?? "cloudpad"
    }

    private func dayKey(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }
}

// MARK: – Week navigator

struct WeekNavigator: View {
    @Binding var weekOffset: Int
    let weekDays: [Date]

    var body: some View {
        HStack {
            navButton(systemImage: "chevron.left") { weekOffset -= 1 }
            Spacer()
            Text(weekLabel)
                .font(.caption)
                .foregroundColor(Color(hex: "#9a9490"))
                .onTapGesture { weekOffset = 0 }
            Spacer()
            navButton(systemImage: "chevron.right") { weekOffset += 1 }
        }
    }

    private func navButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "#9a9490"))
                .frame(width: 34, height: 34)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#e8e4de"), lineWidth: 1)
                )
        }
    }

    private var weekLabel: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        let fmtFull = DateFormatter()
        fmtFull.dateFormat = "d MMM yyyy"
        return "\(fmt.string(from: first)) – \(fmtFull.string(from: last))"
    }
}

// MARK: – Day card row

struct DayCard: View {
    @EnvironmentObject var notesVM: NotesViewModel
    let date: Date
    let padKey: String

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        HStack(spacing: 14) {
            // Date badge
            VStack(spacing: 1) {
                Text(abbrevDay)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isToday ? .white : Color(hex: "#9a9490"))
                Text(dayNumber)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(isToday ? .white : Color(hex: "#1a1714"))
            }
            .frame(width: 42, height: 42)
            .background(isToday ? Color.accentColor : Color(hex: "#f7f4f0"))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(fullDayLabel)
                    .font(.subheadline)
                    .fontWeight(isToday ? .semibold : .regular)
                    .foregroundColor(Color(hex: "#1a1714"))

                let count = notesVM.tasks(for: padKey).filter { !$0.isDivider }.count
                Text(count == 0 ? "No tasks" : "\(count) task\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#9a9490"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#c4bfb8"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        // Divider between rows via overlay on bottom
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#f0ece6")),
            alignment: .bottom
        )
    }

    private var abbrevDay: String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEE"
        return fmt.string(from: date).uppercased()
    }

    private var dayNumber: String {
        let fmt = DateFormatter(); fmt.dateFormat = "d"
        return fmt.string(from: date)
    }

    private var fullDayLabel: String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEEE, d MMMM"
        return fmt.string(from: date)
    }
}

// MARK: – Special pad row

struct SpecialPadCard: View {
    let pad: (key: String, label: String, icon: String)
    let notesVM: NotesViewModel

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: pad.icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color(hex: "#f0ece6"))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(pad.label)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#1a1714"))

                let count = notesVM.tasks(for: pad.key).filter { !$0.isDivider }.count
                Text(count == 0 ? "No tasks" : "\(count) task\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#9a9490"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#c4bfb8"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#f0ece6")),
            alignment: .bottom
        )
    }
}

// MARK: – Settings tab wrapper

struct SettingsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            SettingsContent()
                .environmentObject(appState)
        }
    }
}
