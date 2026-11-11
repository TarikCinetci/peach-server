import Foundation
import Photos

enum PhotoSaver {
    static func save(_ url: URL, isVideo: Bool) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw APIError.message("Fotoğraflar izni verilmedi. Ayarlar'dan izin verebilirsin.")
        }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            request.addResource(with: isVideo ? .video : .photo, fileURL: url, options: options)
        }
    }
}
