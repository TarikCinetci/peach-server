import Foundation
import SwiftData

@Model
final class DownloadRecord {
    var id: UUID = UUID()
    var sourceURL: String = ""
    var title: String = ""
    var author: String = ""
    var platformRaw: String = "other"
    var date: Date = Date()
    /// Belgeler klasöründeki dosya adları.
    var fileNames: [String] = []
    /// fileNames ile aynı sırada: "video" | "image" | "audio"
    var kinds: [String] = []

    init(sourceURL: String, title: String, author: String, platform: Platform, fileNames: [String], kinds: [String]) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.title = title
        self.author = author
        self.platformRaw = platform.rawValue
        self.date = Date()
        self.fileNames = fileNames
        self.kinds = kinds
    }

    var platform: Platform { Platform(rawValue: platformRaw) ?? .other }
    var fileURLs: [URL] { fileNames.map { FileStore.url($0) } }
    var firstKind: String { kinds.first ?? "video" }
}
