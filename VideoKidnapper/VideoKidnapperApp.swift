import SwiftUI

/// VideoKidnapper for iOS, iPadOS and macOS.
///
/// An App Store-safe video editor: import clips from the photo library,
/// trim them, add styled captions, and export MP4 or GIF.
///
/// Web downloading is intentionally not included: downloading third-party
/// videos would violate App Store Review Guideline 5.2.3 and the terms of
/// the sites involved.
@main
struct VideoKidnapperApp: App {
    @StateObject private var store = VideoProjectStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
