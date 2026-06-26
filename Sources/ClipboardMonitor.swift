import AppKit

final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    var isPaused = false
    private var pauseResumeWorkItem: DispatchWorkItem?

    // nspasteboard.org convention markers. Apps set these to tell clipboard
    // managers a copied item is sensitive (passwords) or shouldn't be recorded.
    private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private init() {}

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pause(for duration: TimeInterval = 1.5) {
        isPaused = true
        pauseResumeWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.lastChangeCount = NSPasteboard.general.changeCount
            self.isPaused = false
        }
        pauseResumeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func checkClipboard() {
        guard !isPaused else { return }
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if let excluded = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Preferences.shared.excludedBundleIDs.contains(excluded) { return }

        // Skip items apps flag as concealed (e.g. passwords) or transient, so
        // sensitive content is never written to the on-disk history.
        if let types = pb.types,
           types.contains(Self.concealedType) || types.contains(Self.transientType) {
            AppLogger.shared.log("Skipped clipboard item flagged concealed/transient")
            return
        }

        captureClipboard(pb)
    }

    private func captureClipboard(_ pb: NSPasteboard) {
        // 1. File URL(s) — checked before image because NSImage(pasteboard:) will
        //    resolve copied image *files* into images, hiding them as file copies.
        //    A multi-file copy puts several items on the pasteboard; pb.string(forType:)
        //    returns only the first, so read every item and store them newline-joined
        //    (file URLs are percent-encoded, so a newline separator is unambiguous).
        let fileURLs = (pb.pasteboardItems ?? []).compactMap { item -> String? in
            guard let s = item.string(forType: .fileURL), !s.isEmpty else { return nil }
            return s
        }
        if !fileURLs.isEmpty {
            AppLogger.shared.log("Captured \(fileURLs.count) file URL(s)")
            ClipboardHistory.shared.add(ClipItem(
                id: UUID(), type: .fileURL,
                stringValue: fileURLs.joined(separator: "\n"), imageData: nil, timestamp: Date()
            ))
            return
        }

        // 2. Image
        if let image = NSImage(pasteboard: pb), let data = image.tiffRepresentation {
            AppLogger.shared.log("Captured image (\(data.count) bytes)")
            ClipboardHistory.shared.add(ClipItem(
                id: UUID(), type: .image,
                stringValue: nil, imageData: data, timestamp: Date()
            ))
            return
        }

        // 3. Plain text — always preferred over rich formats for clean display
        if let str = pb.string(forType: .string), !str.isEmpty {
            var richData: Data? = nil
            var richFormat: ClipType? = nil
            // Always capture rich formatting; the match-style modifier strips it on paste.
            if let rtf = pb.data(forType: .rtf) {
                richData = rtf
                richFormat = .rtf
            } else if let html = pb.data(forType: .html) {
                richData = html
                richFormat = .html
            }
            AppLogger.shared.log("Captured text (\(str.count) chars\(richFormat != nil ? ", with \(richFormat!) formatting" : ""))")
            ClipboardHistory.shared.add(ClipItem(
                id: UUID(), type: .string,
                stringValue: str, imageData: nil, timestamp: Date(),
                richData: richData, richFormat: richFormat
            ))
            return
        }

        // 4. RTF — extract plain text so no markup code is shown
        if let data = pb.data(forType: .rtf),
           let attrStr = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            let plain = attrStr.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty {
                ClipboardHistory.shared.add(ClipItem(
                    id: UUID(), type: .string,
                    stringValue: plain, imageData: nil, timestamp: Date()
                ))
                return
            }
        }

        // 5. HTML — extract plain text. We deliberately AVOID the NSAttributedString
        //    HTML importer here: it is WebKit-backed and can synchronously load remote
        //    resources referenced inside untrusted clipboard markup. Plain-text
        //    extraction only needs a tag strip + entity decode, which has no network surface.
        if let data = pb.data(forType: .html),
           let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
            let plain = plainText(fromHTML: html).trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty {
                ClipboardHistory.shared.add(ClipItem(
                    id: UUID(), type: .string,
                    stringValue: plain, imageData: nil, timestamp: Date()
                ))
            }
        }
    }

    /// Converts HTML markup to readable plain text without invoking the WebKit-backed
    /// NSAttributedString importer (which can fetch remote resources from untrusted markup).
    private func plainText(fromHTML html: String) -> String {
        var s = html

        // Drop script/style blocks wholesale so their source doesn't leak into the text.
        s = s.replacingOccurrences(
            of: "(?is)<(script|style)[^>]*>.*?</\\1>", with: "", options: .regularExpression)

        // Preserve line structure for common break/block elements.
        s = s.replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(
            of: "(?i)</(p|div|li|tr|h[1-6]|blockquote)>", with: "\n", options: .regularExpression)

        // Strip all remaining tags.
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // Decode the most common named entities.
        let named = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                     "&apos;": "'", "&#39;": "'", "&nbsp;": " "]
        for (entity, char) in named { s = s.replacingOccurrences(of: entity, with: char) }

        // Decode numeric entities (&#1234; and &#x1F600;).
        return decodeNumericEntities(in: s)
    }

    private func decodeNumericEntities(in string: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9A-Fa-f]+);") else { return string }
        let result = NSMutableString(string: string)
        let matches = regex.matches(in: string, range: NSRange(location: 0, length: result.length))
        // Replace from the end so earlier match ranges stay valid as we mutate.
        for match in matches.reversed() {
            let isHex = result.substring(with: match.range(at: 1)).lowercased() == "x"
            let digits = result.substring(with: match.range(at: 2))
            guard let code = UInt32(digits, radix: isHex ? 16 : 10),
                  let scalar = Unicode.Scalar(code) else { continue }
            result.replaceCharacters(in: match.range(at: 0), with: String(scalar))
        }
        return result as String
    }
}
