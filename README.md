# VideoKidnapper for iOS, iPadOS and macOS

A from-scratch SwiftUI rewrite of the VideoKidnapper concept, designed to be
**App Store-safe**: it edits videos the user already owns (photo library) and
deliberately omits web downloading, which would violate App Store Review
Guideline 5.2.3. The Python desktop app
([AES256Afro/VideoKidnapper](https://github.com/AES256Afro/VideoKidnapper))
keeps the downloading workflow on desktop; this app is its App Store sibling.

## What's implemented (MVP)

- **Import** — system photo picker for videos (nothing uploaded, all on-device)
- **Trim** — in/out range selection with preview playback
- **Captions** — multiple styled captions (size, bold, color, outline, shadow),
  timed and positioned, burned into the export exactly as styled
- **Export** — MP4 (highest quality) or GIF, with framing presets
  (Original / 16:9 / 9:16 / 1:1), progress reporting, Share sheet, and
  save-to-photo-library
- Multiplatform target: iPhone + iPad + Mac from one codebase
  (`TARGETED_DEVICE_FAMILY = 1,2,6`), iOS/iPadOS 17+, macOS 14+

## Requirements

- A Mac with **Xcode 15+**
- An Apple Developer Program membership (for device testing, TestFlight,
  and App Store submission)
- Your Development Team selected in Xcode (Signing & Capabilities)

> Note: this project was scaffolded without access to Xcode, so it has not
> been compile-verified. Open it, build, and fix any diagnostics Xcode
> reports — the structure follows standard multiplatform SwiftUI conventions.

## Get it running

1. Copy this folder to your Mac and open `VideoKidnapper.xcodeproj` in Xcode.
2. Select the **VideoKidnapper** target → **Signing & Capabilities** →
   choose your **Team**. The bundle ID is `com.aes256.videokidnapper`
   (change it if you prefer; it must match the identifier you register).
3. Pick a run destination (iPhone simulator, iPad simulator, or My Mac)
   and press **Run**.

## Ship it: App Store checklist

1. **Apple Developer Program License Agreement** — App Store Connect currently
   shows an updated agreement that the Account Holder must accept before
   submissions. Accept it in the developer account first.
2. **Register the identifier** — Certificates, Identifiers & Profiles →
   Identifiers → register `com.aes256.videokidnapper` (or your chosen ID)
   as an App ID.
3. **Create the app record** — App Store Connect → My Apps → **+** → New App.
   One record covers iOS, iPadOS and macOS (add each platform under the
   same app).
4. **Archive** — in Xcode: Product → Archive (with an "Any iOS Device" /
   release destination), then Distribute App → App Store Connect.
   Repeat per platform, or use one archive per platform.
5. **TestFlight** — builds appear under TestFlight within the app record;
   invite testers before submitting for review.
6. **App Store listing** — name, subtitle, description, keywords, support URL
   (`https://videokidnapper.com`), privacy policy URL, categories
   (Photo & Video), age rating questionnaire, and screenshots per device
   size. Export a few clips from the app itself for screenshots.
7. **Submit for review.**

The App Store Connect API key ("Muse build key", Key ID `VT8286ZN2U`)
can drive CI uploads (e.g. `xcrun altool` / App Store Connect API)
once builds are automated.

## Project layout

```
VideoKidnapper/
├── VideoKidnapperApp.swift      # App entry
├── Models/MediaModels.swift     # TrimRange, Caption, export presets
├── Services/
│   ├── VideoProjectStore.swift  # @MainActor session state
│   ├── VideoImporter.swift      # PhotosPicker → temp file (Transferable)
│   ├── VideoCompositor.swift    # AVFoundation: trim + caption overlays + reframing
│   └── VideoExporter.swift      # MP4 / GIF export, save to photo library
├── Views/
│   ├── ContentView.swift        # Import → Trim → Captions → Export steps
│   ├── ImportView.swift
│   ├── TrimView.swift
│   ├── CaptionsView.swift       # list + styled caption editor
│   └── ExportView.swift
├── Components/
│   ├── PlayerView.swift         # VideoPlayer wrapper
│   ├── ColorHex.swift           # hex <-> Color helpers
│   └── Formatting.swift         # time formatting
├── Assets.xcassets              # AppIcon (generated) + AccentColor
└── VideoKidnapper.entitlements  # macOS sandbox (App Store requirement)
```

## Roadmap ideas

- Motion-tracked captions (Vision framework person/object tracking)
- SRT/VTT import, speech-to-caption (on-device Speech framework)
- Overlay images/stickers, color adjustments (CIFilter video composition)
- 9:16 blurred-background fill, transitions between ranges
- iCloud-synced projects, share extension ("Edit in VideoKidnapper")

## App Store screenshots

Screenshots must be captured from the actual running app (simulator or
device) — they can't be made up front. Once the app builds on your Mac:

1. Run it in the simulator for each device class and use
   **File → New Screen Shot** (or `Cmd+S`) at 100% scale.
2. Needed sizes (portrait or landscape, up to 10 per size):
   - **iPhone 6.7"**: 1290 × 2796
   - **iPhone 6.5"**: 1242 × 2688 (or 1284 × 2778)
   - **iPad Pro 13"**: 2064 × 2752 portrait / 2752 × 2064 landscape
   - **Mac**: 2880 × 1800 (2560 × 1600 and 1440 × 900 also accepted)
3. Suggested shot list: Import (empty state), Trim (timeline + preview),
   Captions (styled caption on video), Export (framing presets + progress),
   and one finished 9:16 export.
4. The desktop repo's `assets/screenshots/` and `assets/branding/store-*`
   files show the established visual language — keep the navy/cream/orange
   identity consistent.

## License

Proprietary — © Christopher Courtney. (Choose a license before distributing.)
