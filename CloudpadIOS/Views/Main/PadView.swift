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
        ZStack(alignment: .bottom) {
            Color(hex: "#f7f4f0").ignoresSafeArea()

            VStack(spacing: 0) {
                if tasks.isEmpty {
                    EmptyPadView()
                } else {
                    List {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
                            if task.isDivider {
                                DividerRow(text: task.text)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(.init(top: 16, leading: 20, bottom: 4, trailing: 20))
                                    .listRowSeparator(.hidden)
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
                                .listRowBackground(Color.white)
                                .listRowInsets(.init(top: 0, leading: 20, bottom: 0, trailing: 16))
                                .listRowSeparatorTint(Color(hex: "#f0ece6"))
                            }
                        }
                        .onMove { from, to in
                            guard let token = appState.token else { return }
                            notesVM.moveTask(padKey: padKey, from: from, to: to, token: token)
                        }

                        // Bottom spacer so content isn't hidden behind the input bar
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

            // Floating add-task bar
            VStack(spacing: 0) {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(hex: "#e8e4de"))

                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(
                            inputFocused || !newTaskText.isEmpty
                                ? appState.accentColor
                                : Color(hex: "#c4bfb8")
                        )

                    TextField("Add a task…", text: $newTaskText)
                        .focused($inputFocused)
                        .onSubmit { submitNewTask() }

                    if !newTaskText.isEmpty {
                        Button { submitNewTask() } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(appState.accentColor)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .padding(.bottom, 4)
                .background(Color.white)
            }
        }
        .navigationTitle(padTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    Task { await toggleShare() }
                } label: {
                    Image(systemName: note?.isShared == true ? "link.circle.fill" : "link")
                        .foregroundColor(
                            note?.isShared == true
                                ? appState.accentColor
                                : Color(hex: "#9a9490")
                        )
                }

                EditButton()
                    .foregroundColor(appState.accentColor)
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
        if padKey.count == 10, padKey.contains("-") {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            if let date = fmt.date(from: padKey) {
                if Calendar.current.isDateInToday(date) { return "Today" }
                let out = DateFormatter()
                out.dateFormat = "EEEE, d MMM"
                return out.string(from: date)
            }
        }
        return Config.specialPads.first(where: { $0.key == padKey })?.label ?? padKey
    }
}

// MARK: – Empty state

struct EmptyPadView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundColor(Color(hex: "#e8e4de"))
            Text("No tasks yet")
                .font(.subheadline)
                .foregroundColor(Color(hex: "#9a9490"))
            Text("Type below to add your first task")
                .font(.caption)
                .foregroundColor(Color(hex: "#c4bfb8"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#f7f4f0"))
    }
}

// MARK: – Task row

struct TaskRow: View {
    let task: Task
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
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

struct DividerRow: View {
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
