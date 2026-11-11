import Foundation

struct MediaInfo: Decodable, Equatable {
    let title: String
    let author: String
    let thumbnail: String
    let duration: Double?
    let kind: String        // "video" | "gallery"
    let count: Int
    let qualities: [String]
    let platform: String
}

struct JobCreated: Decodable {
    let id: String
}

struct RemoteFile: Decodable {
    let index: Int
    let name: String
    let size: Int
    let kind: String        // "video" | "image" | "audio"
}

struct JobStatus: Decodable {
    let id: String
    let status: String      // queued | downloading | done | error
    let progress: Double
    let error: String?
    let files: [RemoteFile]
}

struct ServerError: Decodable {
    let detail: String
}

struct OKResponse: Decodable {
    let ok: Bool
}

enum APIError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): text
        }
    }
}

func qualityLabel(_ q: String) -> String {
    switch q {
    case "best": "En iyi"
    case "audio": "Yalnızca ses"
    default: q + "p"
    }
}
