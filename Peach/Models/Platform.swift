import SwiftUI

enum Platform: String, CaseIterable {
    case instagram, tiktok, youtube, x, facebook, reddit, pinterest, threads, vimeo, other

    var name: String {
        switch self {
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .youtube: "YouTube"
        case .x: "X"
        case .facebook: "Facebook"
        case .reddit: "Reddit"
        case .pinterest: "Pinterest"
        case .threads: "Threads"
        case .vimeo: "Vimeo"
        case .other: "Web"
        }
    }

    var symbol: String {
        switch self {
        case .instagram: "camera.fill"
        case .tiktok: "music.note"
        case .youtube: "play.rectangle.fill"
        case .x: "bubble.left.fill"
        case .facebook: "person.2.fill"
        case .reddit: "text.bubble.fill"
        case .pinterest: "pin.fill"
        case .threads: "at"
        case .vimeo: "film.fill"
        case .other: "globe"
        }
    }

    var color: Color {
        switch self {
        case .instagram: Color(red: 0.93, green: 0.25, blue: 0.55)
        case .tiktok: Color(red: 0.0, green: 0.90, blue: 0.86)
        case .youtube: Color(red: 1.0, green: 0.23, blue: 0.19)
        case .x: Color(red: 0.75, green: 0.78, blue: 0.85)
        case .facebook: Color(red: 0.25, green: 0.52, blue: 1.0)
        case .reddit: Color(red: 1.0, green: 0.42, blue: 0.13)
        case .pinterest: Color(red: 0.90, green: 0.13, blue: 0.20)
        case .threads: Color(red: 0.80, green: 0.80, blue: 0.80)
        case .vimeo: Color(red: 0.10, green: 0.72, blue: 0.92)
        case .other: Theme.accent
        }
    }

    static let featured: [Platform] = [.instagram, .tiktok, .youtube, .x, .facebook, .reddit, .pinterest]

    static func detect(_ link: String) -> Platform {
        let host = (URL(string: link)?.host() ?? link).lowercased()
        if host.contains("instagram") { return .instagram }
        if host.contains("tiktok") { return .tiktok }
        if host.contains("youtu") { return .youtube }
        if host.contains("twitter") || host == "x.com" || host.hasSuffix(".x.com") || host == "t.co" { return .x }
        if host.contains("facebook") || host.contains("fb.watch") { return .facebook }
        if host.contains("redd") { return .reddit }
        if host.contains("pinterest") || host.contains("pin.it") { return .pinterest }
        if host.contains("threads") { return .threads }
        if host.contains("vimeo") { return .vimeo }
        return .other
    }
}
