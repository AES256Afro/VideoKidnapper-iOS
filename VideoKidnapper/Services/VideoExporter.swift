import AVFoundation
import Foundation
import ImageIO
import Photos
import UniformTypeIdentifiers

/// MP4 / GIF export and saving to the photo library.
enum VideoExporter {

    /// Export the composed video as an MP4 file in a temp URL.
    static func exportMP4(
        composed: ComposedVideo,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        guard let session = AVAssetExportSession(
            asset: composed.composition, presetName: AVAssetExportPresetHighestQuality)
        else {
            throw CompositorError.exportSessionUnavailable
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoKidnapper-\(UUID().uuidString)")
            .appendingPathExtension("mp4")
        session.outputURL = url
        session.outputFileType = .mp4
        session.videoComposition = composed.videoComposition
        session.timeRange = composed.timeRange
        session.shouldOptimizeForNetworkUse = true

        let poll = Task {
            while !Task.isCancelled {
                let p = session.progress
                await MainActor.run { progress(Double(p)) }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
        await session.export()
        poll.cancel()

        if let error = session.error { throw error }
        guard session.status == .completed else {
            throw CompositorError.exportSessionUnavailable
        }
        await MainActor.run { progress(1) }
        return url
    }

    /// Export the trimmed range as an animated GIF (capped size/frames).
    static func exportGIF(
        composed: ComposedVideo,
        fps: Int = 12,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let duration = CMTimeGetSeconds(composed.timeRange.duration)
        guard duration > 0 else { throw CompositorError.gifFailed }
        let frameCount = min(90, max(1, Int(duration * Double(fps))))

        let generator = AVAssetImageGenerator(asset: composed.composition)
        generator.videoComposition = composed.videoComposition
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        // Keep GIFs small: cap width at 480pt, preserve aspect.
        let renderSize = composed.videoComposition.renderSize
        let scale = min(1, 480 / renderSize.width)
        generator.maximumSize = CGSize(
            width: renderSize.width * scale, height: renderSize.height * scale)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VideoKidnapper-\(UUID().uuidString)")
            .appendingPathExtension("gif")
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.gif.identifier as CFString, frameCount, nil)
        else {
            throw CompositorError.gifFailed
        }
        let gifProps = [
            kCGImagePropertyGIFDictionary as String:
                [kCGImagePropertyGIFLoopCount as String: 0]
        ] as CFDictionary
        CGImageDestinationSetProperties(dest, gifProps)
        let frameProps = [
            kCGImagePropertyGIFDictionary as String:
                [kCGImagePropertyGIFDelayTime as String: 1.0 / Double(fps)]
        ] as CFDictionary

        for i in 0..<frameCount {
            let time = CMTime(
                seconds: Double(i) / Double(fps), preferredTimescale: 600)
            let image = try await generator.image(at: time)
            CGImageDestinationAddImage(dest, image, frameProps)
            await MainActor.run { progress(Double(i + 1) / Double(frameCount)) }
        }
        guard CGImageDestinationFinalize(dest) else { throw CompositorError.gifFailed }
        return url
    }

    /// Save an exported file to the photo library (asks permission if needed).
    static func saveToPhotoLibrary(fileURL: URL, isVideo: Bool) async throws {
        let status = await requestAddOnlyAuthorization()
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.notAuthorized
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                if isVideo {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
                }
            }, completionHandler: { success, error in
                if let error {
                    cont.resume(throwing: error)
                } else if success {
                    cont.resume()
                } else {
                    cont.resume(throwing: PhotoLibraryError.saveFailed)
                }
            })
        }
    }

    private static func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                cont.resume(returning: status)
            }
        }
    }
}

enum PhotoLibraryError: LocalizedError {
    case notAuthorized
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Photo library access wasn't granted, so the file couldn't be saved."
        case .saveFailed:
            return "Saving to the photo library failed."
        }
    }
}
