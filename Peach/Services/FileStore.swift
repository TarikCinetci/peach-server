import Foundation

/// İndirilen dosyalar uygulamanın Belgeler klasöründe durur (Dosyalar uygulamasında da görünür).
enum FileStore {
    static var folder: URL { URL.documentsDirectory }

    static func url(_ name: String) -> URL {
        folder.appending(path: name)
    }

    static func uniqueURL(for rawName: String) -> URL {
        var name = rawName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.hasPrefix(".") { name = "dosya" + name }
        var candidate = url(name)
        let base = candidate.deletingPathExtension().lastPathComponent
        let ext = candidate.pathExtension
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = url(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        }
        return candidate
    }

    static func delete(_ names: [String]) {
        for name in names {
            try? FileManager.default.removeItem(at: url(name))
        }
    }
}
