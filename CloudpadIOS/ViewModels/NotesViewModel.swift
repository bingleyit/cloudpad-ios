import Foundation
import Combine

@MainActor
final class NotesViewModel: ObservableObject {
    @Published var notesByKey: [String: Note] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Debounce auto-save
    private var saveTasks: [String: Task<Void, Never>] = [:]

    func loadAll(token: String) async {
        isLoading = true
        do {
            let notes = try await APIService.shared.fetchAllNotes(token: token)
            notesByKey = Dictionary(uniqueKeysWithValues: notes.map { ($0.padKey, $0) })
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func tasks(for padKey: String) -> [Task] {
        notesByKey[padKey]?.tasks ?? []
    }

    func addTask(padKey: String, text: String, token: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var list = tasks(for: padKey)
        if trimmed.hasPrefix("---") {
            let label = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            list.append(Task(text: label.isEmpty ? "—" : label, type: "divider"))
        } else {
            list.append(Task(text: trimmed))
        }
        persist(padKey: padKey, tasks: list, token: token)
    }

    func toggleTask(padKey: String, index: Int, token: String) {
        var list = tasks(for: padKey)
        guard index < list.count, !list[index].isDivider else { return }
        list[index].done.toggle()
        persist(padKey: padKey, tasks: list, token: token)
    }

    func deleteTask(padKey: String, index: Int, token: String) {
        var list = tasks(for: padKey)
        guard index < list.count else { return }
        list.remove(at: index)
        persist(padKey: padKey, tasks: list, token: token)
    }

    func moveTask(padKey: String, from: IndexSet, to: Int, token: String) {
        var list = tasks(for: padKey)
        list.move(fromOffsets: from, toOffset: to)
        persist(padKey: padKey, tasks: list, token: token)
    }

    // Immediately update local state and schedule a debounced network save
    private func persist(padKey: String, tasks: [Task], token: String) {
        let body = tasks.jsonString
        if var note = notesByKey[padKey] {
            note.body = body
            notesByKey[padKey] = note
        } else {
            notesByKey[padKey] = Note(
                id: UUID().uuidString, padKey: padKey,
                title: padKey, body: body,
                isShared: false, shareToken: nil, updatedAt: ""
            )
        }
        scheduleAutoSave(padKey: padKey, token: token)
    }

    private func scheduleAutoSave(padKey: String, token: String) {
        saveTasks[padKey]?.cancel()
        saveTasks[padKey] = Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s debounce
            guard !Task.isCancelled else { return }
            await self.flushSave(padKey: padKey, token: token)
        }
    }

    func flushSave(padKey: String, token: String) async {
        guard let note = notesByKey[padKey] else { return }
        do {
            try await APIService.shared.saveNote(
                padKey: padKey, title: note.title, body: note.body, token: token
            )
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    func shareNote(padKey: String, token: String) async -> String? {
        do {
            let resp = try await APIService.shared.shareNote(padKey: padKey, token: token)
            if var note = notesByKey[padKey] {
                note.isShared = true
                note.shareToken = resp.token
                notesByKey[padKey] = note
            }
            return resp.shareUrl
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func unshareNote(padKey: String, token: String) async {
        do {
            try await APIService.shared.unshareNote(padKey: padKey, token: token)
            if var note = notesByKey[padKey] {
                note.isShared = false
                notesByKey[padKey] = note
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
