import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ActiveDownload: Identifiable {
    let id = UUID()
    let title: String
    let platform: Platform
    var progress: Double = 0
    var stage: String = "Sunucu hazırlıyor…"
    var error: String?
    var finished = false

    init(title: String, platform: Platform) {
        self.title = title
        self.platform = platform
    }
}

@MainActor
@Observable
final class DownloadManager {
    var active: [ActiveDownload] = []

    func start(link: String, info: MediaInfo, quality: String, saveToPhotos: Bool, context: ModelContext) {
        let item = ActiveDownload(title: info.title, platform: Platform.detect(link))
        withAnimation(.spring) { active.insert(item, at: 0) }
        Task {
            do {
                try await run(item: item, link: link, info: info, quality: quality, saveToPhotos: saveToPhotos, context: context)
                item.progress = 1
                item.finished = true
                try? await Task.sleep(for: .seconds(2.5))
                dismiss(item)
            } catch {
                item.error = error.localizedDescription
            }
        }
    }

    func dismiss(_ item: ActiveDownload) {
        withAnimation(.spring) { active.removeAll { $0.id == item.id } }
    }

    private func run(item: ActiveDownload, link: String, info: MediaInfo, quality: String,
                     saveToPhotos: Bool, context: ModelContext) async throws {
        let api = try APIClient.current()
        let created: JobCreated = try await api.send(
            api.request("/api/jobs", method: "POST", body: ["url": link, "quality": quality]))

        // 1) Sunucu içeriği hazırlarken durumu yokla (ilerlemenin ilk yarısı)
        var status: JobStatus
        var failures = 0
        while true {
            try await Task.sleep(for: .seconds(1))
            do {
                status = try await api.send(api.request("/api/jobs/\(created.id)"))
                failures = 0
            } catch {
                failures += 1
                if failures >= 5 { throw error }
                continue
            }
            item.progress = max(item.progress, status.progress * 0.5)
            if status.status == "done" || status.status == "error" { break }
        }
        if status.status == "error" {
            throw APIError.message(status.error ?? "İndirme başarısız oldu.")
        }
        guard !status.files.isEmpty else {
            throw APIError.message("İndirilecek dosya bulunamadı.")
        }

        // 2) Dosyaları telefona al (ilerlemenin ikinci yarısı)
        let total = Double(status.files.count)
        var names: [String] = []
        var kinds: [String] = []
        var photoError: String?
        for (i, file) in status.files.enumerated() {
            item.stage = status.files.count > 1
                ? "Telefona iniyor (\(i + 1)/\(status.files.count))…"
                : "Telefona iniyor…"
            let request = try api.request("/api/jobs/\(created.id)/files/\(file.index)")
            let temp = try await api.download(request) { fraction in
                Task { @MainActor in
                    item.progress = max(item.progress, 0.5 + (Double(i) + fraction) / total * 0.5)
                }
            }
            let destination = FileStore.uniqueURL(for: file.name)
            try FileManager.default.moveItem(at: temp, to: destination)
            names.append(destination.lastPathComponent)
            kinds.append(file.kind)

            if saveToPhotos && file.kind != "audio" {
                do {
                    try await PhotoSaver.save(destination, isVideo: file.kind == "video")
                } catch {
                    photoError = error.localizedDescription
                }
            }
        }

        context.insert(DownloadRecord(sourceURL: link, title: info.title, author: info.author,
                                      platform: Platform.detect(link), fileNames: names, kinds: kinds))
        try? context.save()

        if let photoError {
            item.stage = "Kitaplığa kaydedildi. Fotoğraflar'a eklenemedi: \(photoError)"
        } else {
            item.stage = saveToPhotos ? "Fotoğraflar'a kaydedildi" : "Kitaplığa kaydedildi"
        }
    }
}
