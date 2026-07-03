import Foundation

struct SnippetFolder: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var snippets: [Snippet]
    /// The always-present, undeletable first folder with a 10-slot cap that
    /// auto-opens with the snippets hotkey for quick number-key pasting.
    var isQuickSnippets: Bool

    init(id: UUID = UUID(), name: String, snippets: [Snippet] = [], isQuickSnippets: Bool = false) {
        self.id = id
        self.name = name
        self.snippets = snippets
        self.isQuickSnippets = isQuickSnippets
    }

    static func makeQuickSnippets() -> SnippetFolder {
        SnippetFolder(
            name: "Quick Snippets",
            snippets: [
                Snippet(title: "Quick Snippet 1 — press 1 to paste (edit me!)",
                        content: "This is Quick Snippet 1. Open the Snippets editor to replace this with your own text."),
                Snippet(title: "Quick Snippet 2 — press 2 to paste (edit me!)",
                        content: "This is Quick Snippet 2. Add up to 10 snippets here and paste any of them with a single number key."),
                Snippet(title: "Quick Snippet 3 — press 3 to paste (edit me!)",
                        content: "This is Quick Snippet 3. The 10th slot pastes with the 0 key."),
            ],
            isQuickSnippets: true
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, name, snippets, isQuickSnippets
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        snippets = try c.decode([Snippet].self, forKey: .snippets)
        // Older persisted data predates this field.
        isQuickSnippets = try c.decodeIfPresent(Bool.self, forKey: .isQuickSnippets) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(snippets, forKey: .snippets)
        try c.encode(isQuickSnippets, forKey: .isQuickSnippets)
    }
}
