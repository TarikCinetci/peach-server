import Foundation
import ImageIO
import UniformTypeIdentifiers
import UIKit

struct ImageExportOptions {
    enum Format: String, CaseIterable, Identifiable {
        case jpeg, png, heic
        var id: String { rawValue }
        var title: String {
            switch self {
            case .jpeg: "JPG"
            case .png: "PNG"
            case .heic: "HEIC"
            }
        }
        var fileExtension: String {
            switch self {
            case .jpeg: "jpg"
            case .png: "png"
            case .heic: "heic"
            }
        }
        var type: UTType {
            switch self {
            case .jpeg: .jpeg
            case .png: .png
            case .heic: .heic
            }
        }
    }

    var format: Format
    var quality: Double
    var maximumSide: Int
    var quarterTurns: Int
    var cropAspectRatio: CGFloat?
}

enum ImageToolEngine {
    static func encode(_ image: UIImage, options: ImageExportOptions) throws -> Data {
        var normalized = normalizedImage(image, maximumSide: options.maximumSide, quarterTurns: options.quarterTurns)
        if let ratio = options.cropAspectRatio, ratio > 0, let cgImage = normalized.cgImage {
            let width = cgImage.width
            let height = cgImage.height
            let sourceRatio = CGFloat(width) / CGFloat(height)
            let cropRect: CGRect
            if sourceRatio > ratio {
                let cropWidth = CGFloat(height) * ratio
                cropRect = CGRect(x: (CGFloat(width) - cropWidth) / 2, y: 0, width: cropWidth, height: CGFloat(height))
            } else {
                let cropHeight = CGFloat(width) / ratio
                cropRect = CGRect(x: 0, y: (CGFloat(height) - cropHeight) / 2, width: CGFloat(width), height: cropHeight)
            }
            if let cropped = cgImage.cropping(to: cropRect) {
                normalized = UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up)
            }
        }
        switch options.format {
        case .jpeg:
            guard let data = normalized.jpegData(compressionQuality: options.quality) else {
                throw APIError.message("JPG görseli oluşturulamadı.")
            }
            return data
        case .png:
            guard let data = normalized.pngData() else {
                throw APIError.message("PNG görseli oluşturulamadı.")
            }
            return data
        case .heic:
            guard let cgImage = normalized.cgImage else {
                throw APIError.message("HEIC görseli oluşturulamadı.")
            }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else {
                throw APIError.message("Bu cihazda HEIC dışa aktarılamıyor.")
            }
            CGImageDestinationAddImage(destination, cgImage, [kCGImageDestinationLossyCompressionQuality: options.quality] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                throw APIError.message("HEIC görseli kaydedilemedi.")
            }
            return data as Data
        }
    }

    private static func normalizedImage(_ image: UIImage, maximumSide: Int, quarterTurns: Int) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let limit = max(1, maximumSide)
        let resizeRatio = min(1, CGFloat(limit) / max(pixelWidth, pixelHeight))
        let size = CGSize(width: image.size.width * resizeRatio, height: image.size.height * resizeRatio)
        let turns = ((quarterTurns % 4) + 4) % 4
        let rotated = turns % 2 == 1
        let outputSize = rotated ? CGSize(width: size.height, height: size.width) : size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            context.cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.cgContext.rotate(by: CGFloat(turns) * .pi / 2)
            image.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }
}
