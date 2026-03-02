import SwiftUI

struct PadView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var notesVM: NotesViewModel
    let padKey: String

    @State private var newTaskText = ""
    @State private var shareURL: String?
    @State private var showShareSheet = false
    @FocusState private var inputFocused: Bool

    var tasks: [Task] { notesVM.tasks(for: padKey) }
    var note: Note? { notesVM.notesByKey[padKey] }

    var body: some View {
        VStack(spacing: 0) {
            // Task list
            List {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
                    if task.isDivider {
                        DividerRow(text: task.text)
                            .listRowBackground(Color.clear)
                            .listRowInsets(.init(top: 16, leading: 16, bottom: 4, trailing: 16))
                    } else {
                        TaskRow(task: task) {
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
                    }
                }
                .onMove { from, to in
                    guard let token = appState.token else { return }
                    notesVM.moveTask(padKey: padKey, from: from, to: to, token: token)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))  // Enable drag handles

            // Add task bar
            HStack(spacing: 10) {
                TextField("Add task…", text: $newTaskText)
                    .focused($inputFocused)
                    .onSubmit { submitNewTask() }
                    .padding(.leading, 4)

                if !newTaskText.isEmpty {
                    Button { submitNewTask() } label: {
                        Image(systemName: "return")
                            .foregroundColor(appState.accentColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "#fafafa"))
            .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#e8e4de")), alignment: .top)
        }
        .navigationTitle(padTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Share button
                Button {
                    Task { await toggleShare() }
                } label: {
                    Image(systemName: note?.isShared == true ? "link.circle.fill" : "link")
                        .foregroundColor(note?.isShared == true ? appState.accentColor : .primary)
                }

                EditButton()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Error", isPresented: .constant(notesVM.errorMessage != nil)) {
            Button("OK") { notesVM.errorMessage = nil }
        } message: {
            Text(notesVM.errorMessage ?? "")
        }
    }

    private func submitNewTask() {
        guard let token = appState.token else { return }
        notesVM.addTask(padKey: padKey, text: newTaskText, token: token)
        newTaskText = ""
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

    private var padTitle: String {
        // Check if this looks like a date key
        if padKey.count == 10, padKey.contains("-") {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            if let date = fmt.date(from: padKey) {
                let out = DateFormatter()
                out.dateFormat = "EEEE, d MMMM"
                return out.string(from: date)
            }
        }
        // Special pad
        return Config.specialPads.first(where: { $0.key == padKey })?.label ?? padKey
    }
}

// MARK: – Task row

struct TaskRow: View {
    let task: Task
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(task.done ? Color(hex: "#c4bfb8") : Color.accentColor)
            }
            .buttonStyle(.plain)

            Text(task.text)
                .strikethrough(task.done)
                .foregroundColor(task.done ? Color(hex: "#c4bfb8") : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

// MARK: – Divider row

struct DividerRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            if !text.isEmpty {
                Text(text.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#9a9490"))
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
