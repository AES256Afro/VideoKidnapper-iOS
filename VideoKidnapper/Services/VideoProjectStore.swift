import AVFoundation
import Foundation

/// Session state for the current editing project.
@MainActor
final class VideoProjectStore: ObservableObject {
    @Published var sourceURL: URL?
    @Published var duration: Double = 0
    @Published var trimStart: Double = 0
    @Published var trimEnd: Double = 0
    @Published var captions: [Caption] = []
    @Published var format: ExportFormat = .mp4
    @Published var aspect: AspectPreset = .original

    @Published var isExporting = false
    @Published var exportProgress: Double = 0
    @Published var exportMessage: String?
    @Published var lastExportURL: URL?

    var hasVideo: Bool { sourceURL != nil }

    func load(url: URL) async {
        sourceURL = url
        let asset = AVURLAsset(url: url)
        do {
            let loaded = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(loaded)
            duration = seconds.isFinite ? seconds : 0
            trimStart = 0
            trimEnd = duration
            captions = []
            exportMessage = nil
            lastExportURL = nil
        } catch {
            exportMessage = "Couldn't read that video: \(error.localizedDescription)"
        }
    }

    func reset() {
        sourceURL = nil
        duration = 0
        trimStart = 0
        trimEnd = 0
        captions = []
        lastExportURL = nil
        exportMessage = nil
    }
}
