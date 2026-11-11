# Peach

Peach is an iOS app for saving publicly accessible video and image posts to the device. It uses the companion FastAPI service in `server/` for link previews and media retrieval.

## Open in Xcode

Open `Peach.xcodeproj`, select the Peach scheme, and run on an iPhone or iOS 26 simulator. The app is built with SwiftUI, SwiftData, and the native Liquid Glass material.

## Connect the server

1. Deploy the existing `server/` service using its `render.yaml` blueprint, or host it somewhere else that runs the Dockerfile.
2. Peach fills in the service address automatically: `https://peach-server-i46v.onrender.com`.
3. Copy the generated `API_KEY` from the Render service's Environment page into Peach under **Ayarlar → API anahtarı**. Peach saves it in iOS Keychain, never in this repository.
4. Use **Bağlantıyı denetle** to confirm the app can reach `/api/ping`.

The app keeps completed downloads in its Documents folder, which is visible in the Files app. When enabled, it also asks for permission to add photos and videos to Photos.

## Supported links

The service currently allows Instagram, TikTok, YouTube, X/Twitter, Facebook, Reddit, Pinterest, Threads, Vimeo, and several other domains. Private or login-only posts may require server-side cookies configured through `COOKIES_B64`.

Save only content you are allowed to use and follow the source platform's rules.
