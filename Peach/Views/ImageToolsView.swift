import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ImageToolsView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var sourceImage: UIImage?
    @State private var outputImage: UIImage?
    @State private var outputURL: URL?
    @State private var format: ImageExportOptions.Format = .jpeg
    @State private var quality = 0.86
    @State private var maximumSide = "2560"
    @State private var quarterTurns = 0
    @State private var cropPreset = "Orijinal"
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Araçlar").font(.system(size: 31, weight: .bold, design: .rounded)).tracking(-1)
                            Text("Fotoğraflarını dönüştür ve düzenle").font(.system(size: 13)).foregroundStyle(.white.opacity(0.58))
                        }
                        Spacer()
                        PeachMark(size: 40)
                    }

                    toolSummary

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        HStack(spacing: 12) {
                            Image(systemName: sourceImage == nil ? "photo.badge.plus" : "arrow.triangle.2.circlepath.camera")
                                .font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.accent)
                                .frame(width: 44, height: 44).background(Theme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sourceImage == nil ? "Fotoğraf seç" : "Başka fotoğraf seç").font(.system(size: 14, weight: .semibold))
                                Text("Fotoğraf cihazında işlenir").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.35))
                        }
                        .padding(14).glassCard(cornerRadius: 20)
                    }
                    .buttonStyle(.plain)
                    .onChange(of: pickerItem) { _, item in Task { await loadImage(item) } }

                    if let sourceImage {
                        editor(for: sourceImage)
                    } else {
                        emptyState
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.orange)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15))
                    }
                    if let statusMessage {
                        Label(statusMessage, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 115)
            }
        }
    }

    private var toolSummary: some View {
        HStack(spacing: 0) {
            feature("arrow.left.arrow.right", "Dönüştür")
            feature("arrow.up.left.and.arrow.down.right", "Boyutlandır")
            feature("rotate.right", "Döndür")
            feature("slider.horizontal.3", "Sıkıştır")
        }
        .padding(.vertical, 16).glassCard(cornerRadius: 20)
    }

    private func feature(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.accent)
            Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.65)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 28, weight: .light)).foregroundStyle(Theme.accent.opacity(0.9))
                .frame(width: 66, height: 66).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
            Text("Fotoğrafını Peach’e getir").font(.system(size: 16, weight: .semibold))
            Text("JPG, PNG ve HEIC arasında dönüştür; boyutunu ayarla, döndür ve sıkıştır.")
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center).lineSpacing(3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30).padding(.horizontal, 24).glassCard(cornerRadius: 22)
    }

    private func editor(for image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Önizleme").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(Int(image.size.width * image.scale)) × \(Int(image.size.height * image.scale)) px")
                    .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
            }
            Image(uiImage: outputImage ?? image)
                .resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 205)
                .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
                .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(alignment: .leading, spacing: 10) {
                Text("ÇIKTI BİÇİMİ").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 8) {
                    ForEach(ImageExportOptions.Format.allCases) { option in
                        Button { format = option; outputURL = nil; outputImage = nil } label: {
                            Text(option.title).font(.system(size: 12, weight: .bold))
                                .foregroundStyle(format == option ? .black.opacity(0.82) : .white.opacity(0.7))
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(format == option ? Theme.accent : .white.opacity(0.08), in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("KIRPMA ORANI").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(.white.opacity(0.5))
                HStack(spacing: 7) {
                    ForEach(["Orijinal", "1:1", "4:5", "16:9"], id: \.self) { preset in
                        Button { cropPreset = preset; outputURL = nil; outputImage = nil } label: {
                            Text(preset).font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(cropPreset == preset ? .black.opacity(0.82) : .white.opacity(0.68))
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(cropPreset == preset ? Theme.accent : .white.opacity(0.08), in: Capsule())
                        }.buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Uzun kenar sınırı").font(.system(size: 12, weight: .medium))
                    Spacer()
                    TextField("2560", text: $maximumSide).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced)).frame(width: 74)
                        .padding(.horizontal, 10).padding(.vertical, 7).background(.white.opacity(0.08), in: Capsule())
                    Text("px").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                }
                Text("Orijinal boyutu korumak için görselin mevcut genişliğinden büyük bir değer gir.")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.42))
            }

            if format != .png {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(format == .jpeg ? "JPG kalitesi" : "HEIC kalitesi").font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(Int(quality * 100))%").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.accent)
                    }
                    Slider(value: $quality, in: 0.35...1, step: 0.05).tint(Theme.accent)
                }
            }

            HStack(spacing: 9) {
                Button { quarterTurns = (quarterTurns + 3) % 4; outputURL = nil; outputImage = nil } label: {
                    Label("Sola", systemImage: "rotate.left").frame(maxWidth: .infinity)
                }
                Button { quarterTurns = (quarterTurns + 1) % 4; outputURL = nil; outputImage = nil } label: {
                    Label("Sağa", systemImage: "rotate.right").frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
            .buttonStyle(.bordered).tint(.white.opacity(0.12))

            Button { exportImage(image) } label: {
                HStack(spacing: 8) {
                    if isProcessing { ProgressView().tint(.black) }
                    else { Image(systemName: "square.and.arrow.down.fill") }
                    Text(isProcessing ? "Hazırlanıyor…" : "Dönüştür ve kaydet")
                }
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.black.opacity(0.83))
                .frame(maxWidth: .infinity).frame(height: 48).background(Theme.accent, in: RoundedRectangle(cornerRadius: 15))
            }
            .disabled(isProcessing)

            if let outputURL {
                HStack(spacing: 10) {
                    ShareLink(item: outputURL) {
                        Label("Paylaş", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    Button { saveToPhotos(outputURL) } label: {
                        Label("Fotoğraflar’a ekle", systemImage: "photo.badge.plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(.white.opacity(0.12))
                }
                .font(.system(size: 11, weight: .semibold)).buttonStyle(.bordered)
            }
        }
        .padding(16).glassCard(cornerRadius: 22)
    }

    @MainActor private func loadImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil
        statusMessage = nil
        outputURL = nil
        outputImage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                throw APIError.message("Fotoğraf açılamadı.")
            }
            sourceImage = image
            maximumSide = String(max(image.cgImage?.width ?? Int(image.size.width), image.cgImage?.height ?? Int(image.size.height)))
            quarterTurns = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor private func exportImage(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        defer { isProcessing = false }
        do {
            let limit = Int(maximumSide) ?? max(image.cgImage?.width ?? 2048, image.cgImage?.height ?? 2048)
            let data = try ImageToolEngine.encode(image, options: ImageExportOptions(format: format, quality: quality, maximumSide: limit, quarterTurns: quarterTurns, cropAspectRatio: cropRatio))
            let stamp = Int(Date().timeIntervalSince1970)
            let url = FileStore.uniqueURL(for: "Peach-\(stamp).\(format.fileExtension)")
            try data.write(to: url, options: .atomic)
            outputURL = url
            outputImage = UIImage(data: data)
            statusMessage = "Düzenlenen görsel Dosyalar’a kaydedildi."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var cropRatio: CGFloat? {
        switch cropPreset {
        case "1:1": 1
        case "4:5": 4.0 / 5.0
        case "16:9": 16.0 / 9.0
        default: nil
        }
    }

    @MainActor private func saveToPhotos(_ url: URL) {
        Task {
            do {
                try await PhotoSaver.save(url, isVideo: false)
                statusMessage = "Fotoğraf arşivine eklendi."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
