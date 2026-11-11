import Foundation

struct APIClient {
    let baseURL: URL
    let apiKey: String
    static let defaultServerURL = "https://peach-server-i46v.onrender.com"

    /// Render'daki Peach API adresine ve cihazda saklanan anahtara bağlanır.
    static func current() throws -> APIClient {
        guard let url = URL(string: defaultServerURL), url.host() != nil else {
            throw APIError.message("Peach sunucu adresi geçersiz.")
        }
        let key = (KeychainStore.loadAPIKey() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return APIClient(baseURL: url, apiKey: key)
    }

    func request(_ path: String, method: String = "GET", body: [String: String]? = nil) throws -> URLRequest {
        guard let url = URL(string: baseURL.absoluteString + path) else {
            throw APIError.message("Sunucu adresi geçersiz.")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 150   // ücretsiz sunucular uykudan ~1 dakikada uyanabilir
        if !apiKey.isEmpty { req.setValue(apiKey, forHTTPHeaderField: "X-API-Key") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        return req
    }

    func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.message("Sunucudan yanıt alınamadı.")
        }
        guard (200..<300).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode(ServerError.self, from: data) {
                throw APIError.message(err.detail)
            }
            throw APIError.message("Sunucu hatası (\(http.statusCode)).")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.message("Sunucu yanıtı anlaşılamadı. Adres doğru mu?")
        }
    }

    /// Dosyayı geçici bir konuma indirir; ilerlemeyi 0...1 olarak bildirir.
    func download(_ req: URLRequest, onProgress: @escaping (Double) -> Void) async throws -> URL {
        final class Box { var observation: NSKeyValueObservation? }
        let box = Box()
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: req) { url, response, error in
                box.observation = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url, let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    continuation.resume(throwing: APIError.message("Dosya sunucudan alınamadı."))
                    return
                }
                // Geçici dosya bu blok bitince silinir; hemen taşı.
                let temp = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
                do {
                    try FileManager.default.moveItem(at: url, to: temp)
                    continuation.resume(returning: temp)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            box.observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                onProgress(progress.fractionCompleted)
            }
            task.resume()
        }
    }
}
