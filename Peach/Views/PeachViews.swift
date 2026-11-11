import SwiftUI
import SwiftData
import Photos
import AVKit
import UIKit

// MARK: - Home

struct HomeView: View {
    var openSettings: () -> Void
    @Environment(DownloadManager.self) private var manager
    @Environment(\.modelContext) private var modelContext
    @State private var link = ""
    @State private var info: MediaInfo?
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var selectedQuality = "best"
    @State private var saveToPhotos = true
    @FocusState private var linkFocused: Bool

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    welcome
                    linkEntry
                    if let errorMessage { errorCard(errorMessage) }
                    if loading { loadingCard }
                    if let info { preview(info) }
                    if !manager.active.isEmpty { activeDownloads }
                    supportedPlatforms
                    footerNote
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 110)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: link) { _, _ in
            info = nil
            errorMessage = nil
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            PeachMark(size: 38)
            Text("peach")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .tracking(-1.2)
            Spacer()
            Button(action: openSettings) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.09), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
            }
            .accessibilityLabel("Ayarlar")
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Güzel şeyler\nsenin olsun.")
                .font(.system(size: 37, weight: .bold, design: .rounded))
                .tracking(-1.4)
                .lineSpacing(-2)
            Text("Bir bağlantı yapıştır. Kaydetmeye hazır.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(.top, 7)
    }

    private var linkEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .foregroundStyle(Theme.accent)
                TextField("Instagram, TikTok, YouTube…", text: $link, axis: .vertical)
                    .font(.system(size: 15))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($linkFocused)
                    .lineLimit(1...3)
                    .submitLabel(.go)
                    .onSubmit { Task { await fetchInfo() } }
                if !link.isEmpty {
                    Button {
                        link = ""
                        info = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.42))
                    }
                } else {
                    Button {
                        if let value = UIPasteboard.general.string { link = value.trimmingCharacters(in: .whitespacesAndNewlines) }
                    } label: {
                        Text("Yapıştır").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accent)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 17)
            .background(.white.opacity(0.085), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.13), lineWidth: 1))

            Button {
                linkFocused = false
                Task { await fetchInfo() }
            } label: {
                HStack(spacing: 9) {
                    if loading { ProgressView().tint(.white) }
                    else { Image(systemName: "sparkles") }
                    Text(loading ? "Bağlantı kontrol ediliyor…" : "İçeriği bul")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.25, green: 0.10, blue: 0.12))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: Theme.accent.opacity(0.24), radius: 18, y: 7)
            }
            .disabled(loading)
        }
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Text(message).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.83))
            Spacer(minLength: 0)
            Button { errorMessage = nil } label: { Image(systemName: "xmark").font(.caption.bold()).foregroundStyle(.white.opacity(0.55)) }
        }
        .padding(15)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 17))
    }

    private var loadingCard: some View {
        HStack(spacing: 13) {
            ProgressView().tint(Theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text("Gönderiye bakıyoruz").font(.system(size: 14, weight: .semibold))
                Text("Sunucu ilk açılışta biraz zaman alabilir.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.54))
            }
            Spacer()
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
    }

    private func preview(_ item: MediaInfo) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(Platform.detect(link).color.opacity(0.2))
                    if let url = URL(string: item.thumbnail), !item.thumbnail.isEmpty {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
                            Image(systemName: Platform.detect(link).symbol).foregroundStyle(Platform.detect(link).color)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    } else {
                        Image(systemName: Platform.detect(link).symbol).font(.title2).foregroundStyle(Platform.detect(link).color)
                    }
                }
                .frame(width: 68, height: 68)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Circle().fill(Platform.detect(link).color).frame(width: 6, height: 6)
                        Text(Platform.detect(link).name.uppercased()).font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(.white.opacity(0.58))
                    }
                    Text(item.title).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                    if !item.author.isEmpty { Text("@\(item.author)").font(.system(size: 12)).foregroundStyle(.white.opacity(0.55)).lineLimit(1) }
                }
                Spacer(minLength: 0)
            }

            if item.kind == "video" && !item.qualities.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("İNDİRME KALİTESİ")
                        .font(.system(size: 10, weight: .bold)).tracking(1)
                        .foregroundStyle(.white.opacity(0.55))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(item.qualities, id: \.self) { option in
                                Button { selectedQuality = option } label: {
                                    HStack(spacing: 5) {
                                        if selectedQuality == option { Image(systemName: "checkmark") }
                                        Text(qualityLabel(option))
                                    }
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(selectedQuality == option ? .black.opacity(0.82) : .white.opacity(0.76))
                                    .padding(.horizontal, 12).padding(.vertical, 9)
                                    .background(selectedQuality == option ? Theme.accent : .white.opacity(0.08), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Text("Varsayılan: en yüksek kalite. Fotoğraf gönderileri orijinal kalitede iner.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.50))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Fotoğraflar orijinal kalitede indirilecek")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }


            Toggle(isOn: $saveToPhotos) {
                Label("Fotoğraflar'a da kaydet", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.82))
            }
            .tint(Theme.accent)
            .scaleEffect(0.96, anchor: .trailing)

            Button {
                guard !loading else { return }
                manager.start(link: normalizedLink, info: item, quality: selectedQuality, saveToPhotos: saveToPhotos, context: modelContext)
                info = nil
                link = ""
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: item.kind == "gallery" ? "square.stack.3d.up.fill" : "arrow.down.to.line")
                    Text(item.kind == "gallery" ? "\(item.count) öğeyi indir" : "Şimdi indir")
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.15), lineWidth: 1))
            }
        }
        .padding(17)
        .glassCard(cornerRadius: 23)
    }

    private var activeDownloads: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("İndirme", subtitle: "İşlem sürüyor")
            ForEach(manager.active) { item in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.12), lineWidth: 3)
                        Circle().trim(from: 0, to: max(0.03, item.progress)).stroke(Theme.gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                        Image(systemName: item.error == nil ? "arrow.down" : "exclamationmark").font(.system(size: 11, weight: .bold))
                    }.frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        Text(item.error ?? item.stage).font(.system(size: 11)).foregroundStyle(item.error == nil ? .white.opacity(0.54) : .orange).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if item.error != nil { Button { manager.dismiss(item) } label: { Image(systemName: "xmark").foregroundStyle(.white.opacity(0.6)) } }
                }
                .padding(13).glassCard(cornerRadius: 17)
            }
        }
    }

    private var supportedPlatforms: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle("Peach nelerle çalışır?", subtitle: "Desteklenen platformlar")
            HStack(spacing: 0) {
                ForEach(Platform.featured.prefix(5), id: \.self) { platform in
                    VStack(spacing: 7) {
                        PlatformLogo(platform: platform)
                            .frame(width: 43, height: 43).background(platform.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        Text(platform.name).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.57)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("Instagram · TikTok · YouTube · X · Facebook ve daha fazlası")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.42)).frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var footerNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill").foregroundStyle(Theme.accent.opacity(0.85))
            Text("İndirdiklerin yalnızca senin cihazında saklanır.")
        }
        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.44))
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
            Text(subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.48))
        }
    }

    private var normalizedLink: String {
        let value = link.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.hasPrefix("http://") || value.hasPrefix("https://") ? value : "https://\(value)"
    }

    @MainActor private func fetchInfo() async {
        let candidate = normalizedLink
        guard !candidate.isEmpty else { errorMessage = "Önce bir bağlantı yapıştır."; return }
        guard let url = URL(string: candidate), let host = url.host(), host.contains(".") else {
            errorMessage = "Bağlantı biçimi geçerli görünmüyor."; return
        }
        loading = true
        errorMessage = nil
        info = nil
        do {
            let api = try APIClient.current()
            let request = try api.request("/api/info", method: "POST", body: ["url": candidate])
            let result: MediaInfo = try await api.send(request)
            info = result
            selectedQuality = result.qualities.first ?? "best"
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - Library

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DownloadRecord.date, order: .reverse) private var records: [DownloadRecord]
    @State private var selected: DownloadRecord?
    @State private var alertMessage: String?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Kitaplığın").font(.system(size: 31, weight: .bold, design: .rounded)).tracking(-1)
                            Text("Kaydettiklerin burada, hep elinin altında.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        PeachMark(size: 39)
                    }
                    if records.isEmpty { emptyState }
                    else {
                        LazyVStack(spacing: 11) {
                            ForEach(records) { record in recordRow(record) }
                        }
                    }
                }
                .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 110)
            }
        }
        .sheet(item: $selected) { record in RecordDetailSheet(record: record) }
        .alert("Bilgi", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("Tamam", role: .cancel) { alertMessage = nil }
        } message: { Text(alertMessage ?? "") }
    }

    private var emptyState: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.12)).frame(width: 102, height: 102)
                Image(systemName: "square.stack.3d.up").font(.system(size: 36, weight: .light)).foregroundStyle(Theme.accent)
            }
            Text("Henüz bir şey yok").font(.system(size: 19, weight: .bold, design: .rounded))
            Text("İlk gönderini indirince burada\ngüzelce yerini alacak.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.53)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 74).glassCard(cornerRadius: 26)
    }

    private func recordRow(_ record: DownloadRecord) -> some View {
        Button { selected = record } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(record.platform.color.opacity(0.16))
                    if let first = record.fileURLs.first, record.firstKind == "image", let image = UIImage(contentsOfFile: first.path) {
                        Image(uiImage: image).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 15))
                    } else {
                        Image(systemName: record.firstKind == "video" ? "play.fill" : "photo.fill")
                            .font(.system(size: 19, weight: .semibold)).foregroundStyle(record.platform.color)
                    }
                }.frame(width: 56, height: 56).clipped()
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.title).font(.system(size: 14, weight: .semibold)).lineLimit(2).multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text(record.platform.name)
                        Text("·")
                        Text(record.date.formatted(date: .abbreviated, time: .omitted))
                        if record.fileNames.count > 1 { Text("· \(record.fileNames.count) dosya") }
                    }.font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 0)
                Menu {
                    Button { selected = record } label: { Label("Aç", systemImage: "play.circle") }
                    ShareLink(items: record.fileURLs) { Label("Paylaş", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) {
                        FileStore.delete(record.fileNames)
                        context.delete(record)
                        try? context.save()
                    } label: { Label("Sil", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.55)).frame(width: 34, height: 40)
                }
            }
            .padding(12).glassCard(cornerRadius: 19)
        }
        .buttonStyle(.plain)
    }
}

struct RecordDetailSheet: View {
    let record: DownloadRecord
    @Environment(\.dismiss) private var dismiss
    @State private var current = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.045, blue: 0.065).ignoresSafeArea()
                VStack(spacing: 18) {
                    if record.fileURLs.indices.contains(current) {
                        let url = record.fileURLs[current]
                        if (record.kinds.indices.contains(current) ? record.kinds[current] : "") == "image",
                           let image = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 430).clipShape(RoundedRectangle(cornerRadius: 18))
                        } else if (record.kinds.indices.contains(current) ? record.kinds[current] : "") == "video" {
                            VideoPlayer(player: AVPlayer(url: url)).frame(height: 350).clipShape(RoundedRectangle(cornerRadius: 18))
                        } else {
                            ContentUnavailableView("Dosya açılamıyor", systemImage: "doc")
                        }
                        Text(record.fileNames[current]).font(.system(size: 12)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                    }
                    if record.fileURLs.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(record.fileURLs.indices, id: \.self) { index in
                                    Button { current = index } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 13).fill(.white.opacity(0.1))
                                            if let image = UIImage(contentsOfFile: record.fileURLs[index].path) {
                                                Image(uiImage: image).resizable().scaledToFill().clipShape(RoundedRectangle(cornerRadius: 13))
                                            } else { Image(systemName: "play.fill").foregroundStyle(Theme.accent) }
                                        }.frame(width: 62, height: 62).overlay(RoundedRectangle(cornerRadius: 13).stroke(current == index ? Theme.accent : .clear, lineWidth: 2))
                                    }
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    ShareLink(items: record.fileURLs) {
                        Label("Paylaş", systemImage: "square.and.arrow.up").font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: 50).background(Theme.gradient, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .foregroundStyle(.black.opacity(0.8))
                }.padding(20)
            }
            .navigationTitle(record.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Bitti") { dismiss() }.foregroundStyle(Theme.accent) } }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Settings

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var checking = false
    @State private var status: ResultMessage?

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 23) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ayarlar").font(.system(size: 31, weight: .bold, design: .rounded)).tracking(-1)
                            Text("Peach bağlantını kişiselleştir.").font(.system(size: 13)).foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer(); PeachMark(size: 39)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Label("Sunucu", systemImage: "server.rack").font(.system(size: 16, weight: .bold, design: .rounded))
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.icloud.fill").foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Render sunucusu").font(.system(size: 12, weight: .semibold))
                                Text(APIClient.defaultServerURL).font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.55)).textSelection(.enabled)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(13).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 7) {
                            Text("API ANAHTARI").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(.white.opacity(0.48))
                            SecureField("Render'daki API_KEY", text: $apiKey)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .padding(14).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                        }
                        Text("Bağlantı adresi uygulamaya tanımlı. Render anahtarını bir kez gir; cihazında güvenli saklanır ve uygulama paketine konmaz.")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.48)).fixedSize(horizontal: false, vertical: true)
                        Button { Task { await ping() } } label: {
                            HStack(spacing: 8) {
                                if checking { ProgressView().tint(Theme.accent) } else { Image(systemName: "waveform.path.ecg") }
                                Text(checking ? "Bağlanıyor…" : "Bağlantıyı denetle")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity).frame(height: 47)
                            .background(Theme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))
                        }.disabled(checking)
                        if let status {
                            Label(status.message, systemImage: status.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(status.success ? .green : .orange)
                        }
                    }
                    .padding(18).glassCard(cornerRadius: 23)

                    VStack(alignment: .leading, spacing: 13) {
                        Label("Nasıl kullanılır", systemImage: "heart.text.square").font(.system(size: 16, weight: .bold, design: .rounded))
                        instructionRow("1", "Gönderi bağlantısını kopyala", "Instagram, TikTok, YouTube ve daha fazlası.")
                        instructionRow("2", "Peach'e yapıştır", "Önizleme ve kalite seçenekleri otomatik gelir.")
                        instructionRow("3", "İndir ve keyfini çıkar", "Dosyalar'da ve istersen Fotoğraflar'da bul.")
                    }
                    .padding(18).glassCard(cornerRadius: 23)

                    HStack(spacing: 9) {
                        Image(systemName: "info.circle.fill").foregroundStyle(Theme.accent)
                        Text("Yalnızca erişimine izin verilen içerikleri kaydet. İçerik sahiplerinin haklarına ve platform kurallarına uy.")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.54)).fixedSize(horizontal: false, vertical: true)
                    }.padding(.horizontal, 3)
                    Text("PEACH · 1.0").font(.system(size: 10, weight: .bold)).tracking(2).foregroundStyle(.white.opacity(0.32)).frame(maxWidth: .infinity).padding(.top, 3)
                }
                .padding(.horizontal, 22).padding(.top, 18).padding(.bottom, 110)
            }
        }
        .onAppear { apiKey = KeychainStore.loadAPIKey() ?? "" }
    }

    private func instructionRow(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.black.opacity(0.8))
                .frame(width: 25, height: 25).background(Theme.accent, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.52))
            }
        }
    }

    @MainActor private func ping() async {
        checking = true
        status = nil
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            status = ResultMessage(success: false, message: "Render API_KEY değerini gir.")
            checking = false
            return
        }
        guard KeychainStore.saveAPIKey(key) else {
            status = ResultMessage(success: false, message: "API anahtarı bu cihazda güvenli saklanamadı.")
            checking = false
            return
        }
        do {
            let api = try APIClient.current()
            let _: OKResponse = try await api.send(api.request("/api/ping"))
            status = ResultMessage(success: true, message: "Sunucu bağlantısı hazır.")
        } catch {
            status = ResultMessage(success: false, message: error.localizedDescription)
        }
        checking = false
    }
}

private struct ResultMessage { let success: Bool; let message: String }

// MARK: - Brand

struct PeachMark: View {
    var size: CGFloat = 42
    var body: some View {
        Image("PeachLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.34, style: .continuous))
            .shadow(color: Theme.accent.opacity(0.30), radius: 12, y: 5)
            .accessibilityLabel("Peach")
    }
}


/// Platform brand marks drawn as scalable SwiftUI vectors.
private struct PlatformLogo: View {
    let platform: Platform

    var body: some View {
        Group {
            switch platform {
            case .instagram:
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white, lineWidth: 2.4).frame(width: 25, height: 25)
                    Circle().stroke(.white, lineWidth: 2.4).frame(width: 11, height: 11)
                    Circle().fill(.white).frame(width: 3.2, height: 3.2).offset(x: 7.5, y: -7.5)
                }
            case .tiktok:
                Text("♪")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Color(red: 0.0, green: 0.9, blue: 0.86), radius: 0, x: -1.8, y: 0)
                    .shadow(color: Color(red: 1.0, green: 0.1, blue: 0.3), radius: 0, x: 1.8, y: 0)
            case .youtube:
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(red: 1.0, green: 0.0, blue: 0.0)).frame(width: 27, height: 19)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: 10))
                        path.addLine(to: CGPoint(x: 8, y: 5))
                        path.closeSubpath()
                    }
                    .fill(.white).frame(width: 8, height: 10)
                }
            case .x:
                Text("𝕏").font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
            case .facebook:
                Text("f").font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.28, green: 0.52, blue: 1.0))
                    .offset(y: 3)
            default:
                Image(systemName: platform.symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(platform.color)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(platform.name)
    }
}
