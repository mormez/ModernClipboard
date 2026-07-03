import Foundation

final class SnippetManager: ObservableObject {
    static let shared = SnippetManager()

    static let quickSnippetsCapacity = 10

    @Published var folders: [SnippetFolder] = []
    private let storageKey = "com.modernclipboard.snippets"

    private init() {
        load()
        migrateQuickSnippetsFolder()
    }

    var quickSnippetsFolderIndex: Int? {
        folders.firstIndex { $0.isQuickSnippets }
    }

    // MARK: - Folder operations

    func addFolder(name: String) {
        folders.append(SnippetFolder(name: name))
        persist()
    }

    func renameFolder(at index: Int, name: String) {
        guard index < folders.count else { return }
        folders[index].name = name
        persist()
    }

    func removeFolder(at index: Int) {
        guard index < folders.count, !folders[index].isQuickSnippets else { return }
        folders.remove(at: index)
        persist()
    }

    func moveFolder(from source: IndexSet, to destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        pinQuickSnippetsFirst()
        persist()
    }

    /// Used by the folders list's drag-to-reorder binding, which replaces the
    /// whole array directly rather than going through `moveFolder`.
    func setFolders(_ newFolders: [SnippetFolder]) {
        folders = newFolders
        pinQuickSnippetsFirst()
        persist()
    }

    private func pinQuickSnippetsFirst() {
        guard let idx = quickSnippetsFolderIndex, idx != 0 else { return }
        let folder = folders.remove(at: idx)
        folders.insert(folder, at: 0)
    }

    // MARK: - Snippet operations

    func addSnippet(_ snippet: Snippet, to folderIndex: Int) {
        guard folderIndex < folders.count else { return }
        if folders[folderIndex].isQuickSnippets,
           folders[folderIndex].snippets.count >= Self.quickSnippetsCapacity {
            AppLogger.shared.log("Quick Snippets folder is full (\(Self.quickSnippetsCapacity) slots) — snippet not added")
            return
        }
        folders[folderIndex].snippets.append(snippet)
        persist()
    }

    func updateSnippet(at snippetIndex: Int, in folderIndex: Int, title: String, content: String) {
        guard folderIndex < folders.count, snippetIndex < folders[folderIndex].snippets.count else { return }
        objectWillChange.send()
        folders[folderIndex].snippets[snippetIndex].title = title
        folders[folderIndex].snippets[snippetIndex].content = content
        persist()
    }

    func removeSnippet(at snippetIndex: Int, from folderIndex: Int) {
        guard folderIndex < folders.count, snippetIndex < folders[folderIndex].snippets.count else { return }
        folders[folderIndex].snippets.remove(at: snippetIndex)
        persist()
    }

    func moveSnippet(in folderIndex: Int, from source: IndexSet, to destination: Int) {
        guard folderIndex < folders.count else { return }
        folders[folderIndex].snippets.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    // MARK: - Persistence

    func persist() {
        guard let data = try? JSONEncoder().encode(folders) else {
            AppLogger.shared.log("Failed to encode snippet folders (\(folders.count) folders)")
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
        NotificationCenter.default.post(name: .snippetsChanged, object: nil)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        guard let loaded = try? JSONDecoder().decode([SnippetFolder].self, from: data) else {
            AppLogger.shared.log("Failed to decode saved snippets — starting with empty snippets")
            return
        }
        folders = loaded
    }

    /// Ensures the Quick Snippets folder exists and sits first, for both fresh
    /// installs and users upgrading from a version predating this feature.
    private func migrateQuickSnippetsFolder() {
        if folders.isEmpty {
            folders = [SnippetFolder.makeQuickSnippets(), SnippetFolder(name: "My Snippets")]
            persist()
            return
        }
        if quickSnippetsFolderIndex == nil {
            folders.insert(SnippetFolder.makeQuickSnippets(), at: 0)
            persist()
        } else {
            pinQuickSnippetsFirst()
        }
    }
}
