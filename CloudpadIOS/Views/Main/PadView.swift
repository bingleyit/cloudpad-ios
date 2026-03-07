import SwiftUI

// MARK: – Pad content view (no navigation chrome – embedded directly in MainView)

struct PadContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notesVM: NotesViewModel
    let padKey: String
    let mode: AppMode

    @State private var shareURL: String?
    @State private var showShareSheet = false

    var tasks: [Task] { notesVM.tasks(for: padKey) }
    var note: Note? { notesVM.notesByKey[padKey] }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if tasks.isEmpty {
                EmptyPadView()
            } else {
                List {
                    // Section header (LISTS mode only – date header is in DaysSubHeader)
                    if mode == .lists, let padLabel = Config.specialPads.first(where: { $0.key == padKey })?.label {
                        Text(padLabel.uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#1a1714"))
                            .listRowBackground(Color.white)
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 16, leading: 20, bottom: 4, trailing: 20))
                    }

                    ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
                        if task.isDivider {
                            PadDividerRow(text: task.text)
                                .listRowBackground(Color.white)
                                .listRowInsets(.init(top: 12, leading: 20, bottom: 4, trailing: 20))
                                .listRowSeparator(.hidden)
                        } else {
                            PadTaskRow(task: task) {
                                guard let token = appState.token else { return }
                                notesVM.toggleTask(padKey: padKey, index: idx, token: token)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    guard let token = appState.token else { return }
                                    notesVM.deleteTask(padKey: padKey, index: idx, token: token)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task { await toggleShare() }
                                } label: {
                                    Label("Share", systemImage: "link")
                                }
                                .tint(appState.accentColor)
                            }
                            .listRowBackground(Color.white)
                            .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 16))
                            .listRowSeparatorTint(Color(hex: "#f0ece6"))
                        }
                    }
                    .onMove { from, to in
                        guard let token = appState.token else { return }
                        notesVM.moveTask(padKey: padKey, from: from, to: to, token: token)
                    }

                    // Bottom padding so FAB doesn't cover last item
                    Color.clear
                        .frame(height: 80)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL { ShareSheet(items: [url]) }
        }
        .alert("Error", isPresented: .constant(notesVM.errorMessage != nil)) {
            Button("OK") { notesVM.errorMessage = nil }
        } message: {
            Text(notesVM.errorMessage ?? "")
        }
    }

    private func toggleShare() async {
        guard let token = appState.token else { return }
        if note?.isShared == true {
            await notesVM.unshareNote(padKey: padKey, token: token)
        } else {
            if let url = await notesVM.shareNote(padKey: padKey, token: token) {
                shareURL = url
                showShareSheet = true
            }
        }
    }
}

// MARK: – Empty state

struct EmptyPadView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.square")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#e8e4de"))
            Text("No tasks yet")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#9a9490"))
            Text("Tap + to add your first task")
                .font(.caption)
                .foregroundColor(Color(hex: "#c4bfb8"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: – Task row (square checkbox to match web)

struct PadTaskRow: View {
    let task: Task
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: task.done ? "checkmark.square.fill" : "square.fill")
                    .font(.system(size: 20))
                    .foregroundColor(task.done ? Color(hex: "#c4bfb8") : Color.accentColor)
            }
            .buttonStyle(.plain)

            Text(task.text)
                .strikethrough(task.done, color: Color(hex: "#c4bfb8"))
                .foregroundColor(task.done ? Color(hex: "#c4bfb8") : Color(hex: "#1a1714"))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 13)
    }
}

// MARK: – Divider row

struct PadDividerRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            if !text.isEmpty {
                Text(text.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#9a9490"))
                    .tracking(0.5)
            }
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#e8e4de"))
        }
    }
}

// MARK: – Share sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
