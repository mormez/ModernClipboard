import AppKit
import Foundation
import UniformTypeIdentifiers

enum ClipType: String, Codable {
    case string
    case rtf
    case html
    case image
    case fileURL
}

struct ClipItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ClipType
    let stringValue: String?
    let imageData: Data?
    let timestamp: Date
    var lastUsedAt: Date? = nil
    // Raw RTF/HTML pasteboard data, captured only when "Preserve formatting" is enabled.
    var richData: Data? = nil
    var richFormat: ClipType? = nil

    var displayTitle: String {
        switch type {
        case .string, .rtf, .html:
            let text = (stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "(empty)" : String(text.prefix(100))
        case .image:
            return "[Image]"
        case .fileURL:
            guard let s = stringValue, !s.isEmpty else { return "[File]" }
            let urls = s.split(separator: "\n").compactMap { URL(string: String($0)) }
            guard let first = urls.first else { return "[File]" }
            let isImage = UTType(filenameExtension: first.pathExtension)?.conforms(to: .image) ?? false
            if urls.count == 1 {
                return "\(isImage ? "[Image]" : "[File]") \(first.lastPathComponent)"
            }
            return "\(isImage ? "[Images]" : "[Files]") \(first.lastPathComponent) + \(urls.count - 1) more"
        }
    }

    var thumbnailImage: NSImage? {
        guard type == .image, let data = imageData else { return nil }
        return NSImage(data: data)
    }

    static func == (lhs: ClipItem, rhs: ClipItem) -> Bool {
        lhs.type == rhs.type &&
        lhs.stringValue == rhs.stringValue &&
        lhs.imageData == rhs.imageData
    }

    static func hasSameContent(_ lhs: ClipItem, _ rhs: ClipItem) -> Bool {
        lhs == rhs
    }
}
