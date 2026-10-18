import AVFoundation
import CoreGraphics
import CoreText
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum CompositorError: LocalizedError {
    case noVideoTrack
    case exportSessionUnavailable
    case gifFailed

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: return "The video has no playable video track."
        case .exportSessionUnavailable: return "Export couldn't be started on this device."
        case .gifFailed: return "The GIF couldn't be written."
        }
    }
}

struct ComposedVideo {
    let composition: AVMutableComposition
    let videoComposition: AVMutableVideoComposition
    /// The trimmed time range, rebased so it starts at zero.
    let timeRange: CMTimeRange
}

/// Builds an AVFoundation composition from the edit: trim + styled captions
/// + aspect reframing. Pure logic — no UI.
enum VideoCompositor {

    static func compose(
        source: AVAsset,
        trimStart: Double,
        trimEnd: Double,
        captions: [Caption],
        aspect: AspectPreset
    ) async throws -> ComposedVideo {
        guard let videoTrack = try await source.loadTracks(withMediaType: .video).first else {
            throw CompositorError.noVideoTrack
        }
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let oriented = orientedSize(naturalSize, preferredTransform)
        let renderSize = aspect.renderSize(for: naturalSize) ?? oriented

        let composition = AVMutableComposition()
        guard
            let compVideoTrack = composition.addMutableTrack(
                withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let compAudioTrack = composition.addMutableTrack(
                withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw CompositorError.noVideoTrack
        }

        let start = CMTime(seconds: trimStart, preferredTimescale: 600)
        let end = CMTime(seconds: trimEnd, preferredTimescale: 600)
        let sourceRange = CMTimeRange(start: start, end: end)
        try compVideoTrack.insertTimeRange(sourceRange, of: videoTrack, at: .zero)
        if let audioTrack = try await source.loadTracks(withMediaType: .audio).first {
            try? compAudioTrack.insertTimeRange(sourceRange, of: audioTrack, at: .zero)
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: sourceRange.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
        layerInstruction.setTransform(
            fillTransform(from: naturalSize, preferredTransform: preferredTransform, to: renderSize),
            at: .zero)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        // Caption overlays via Core Animation.
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

        for caption in captions {
            let localStart = max(0, caption.start - trimStart)
            let localEnd = min(CMTimeGetSeconds(sourceRange.duration), caption.end - trimStart)
            guard localEnd > localStart else { continue }
            let layer = captionLayer(caption, renderSize: renderSize)
            layer.beginTime = AVCoreAnimationBeginTimeAtZero + localStart
            layer.opacity = 0

            let show = CABasicAnimation(keyPath: "opacity")
            show.fromValue = 0
            show.toValue = 1
            show.beginTime = layer.beginTime
            show.duration = 0.05
            show.fillMode = .forwards
            show.isRemovedOnCompletion = false

            let hide = CABasicAnimation(keyPath: "opacity")
            hide.fromValue = 1
            hide.toValue = 0
            hide.beginTime = AVCoreAnimationBeginTimeAtZero + localEnd
            hide.duration = 0.05
            hide.fillMode = .forwards
            hide.isRemovedOnCompletion = false

            layer.add(show, forKey: "show")
            layer.add(hide, forKey: "hide")
            parentLayer.addSublayer(layer)
        }
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer, in: parentLayer)

        return ComposedVideo(
            composition: composition,
            videoComposition: videoComposition,
            timeRange: CMTimeRange(start: .zero, duration: sourceRange.duration))
    }

    // MARK: - Geometry

    /// Display size after the track's preferred transform (rotation) is applied.
    private static func orientedSize(_ natural: CGSize, _ transform: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: natural).applying(transform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }

    /// Scale-to-fill transform: rotate per the preferred transform, scale so
    /// the render size is covered, then center.
    private static func fillTransform(
        from natural: CGSize,
        preferredTransform: CGAffineTransform,
        to render: CGSize
    ) -> CGAffineTransform {
        let oriented = orientedSize(natural, preferredTransform)
        guard oriented.width > 0, oriented.height > 0 else { return preferredTransform }
        let scale = max(render.width / oriented.width, render.height / oriented.height)
        let tx = (render.width - oriented.width * scale) / 2
        let ty = (render.height - oriented.height * scale) / 2
        return preferredTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: tx, y: ty))
    }

    // MARK: - Captions

    private static func captionLayer(_ caption: Caption, renderSize: CGSize) -> CATextLayer {
        let layer = CATextLayer()
        // Scale type relative to a 1080-wide canvas so captions look
        // consistent across render sizes.
        let unit = renderSize.width / 1080
        let fontSize = CGFloat(caption.style.fontSize) * unit
        let fontName = caption.style.isBold ? "Helvetica-Bold" : "Helvetica"

        #if canImport(UIKit)
        let platformFont = UIFont(name: fontName, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize, weight: caption.style.isBold ? .bold : .regular)
        #elseif canImport(AppKit)
        let platformFont = NSFont(name: fontName, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize, weight: caption.style.isBold ? .bold : .regular)
        #endif

        let strokeWidth = caption.style.outlineWidth * unit
        let attributes: [NSAttributedString.Key: Any] = [
            .font: platformFont,
            .foregroundColor: platformColor(hex: caption.style.textColorHex),
            // Negative stroke width = fill + stroke, the classic outlined-caption look.
            .strokeColor: platformColor(hex: caption.style.outlineColorHex),
            .strokeWidth: -strokeWidth,
        ]
        let attributed = NSAttributedString(string: caption.text, attributes: attributes)
        layer.string = attributed
        layer.alignmentMode = .center
        layer.isWrapped = true
        layer.contentsScale = 2

        if caption.style.shadowEnabled {
            layer.shadowColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.6)
            layer.shadowOpacity = 1
            layer.shadowOffset = CGSize(width: 0, height: -2 * unit)
            layer.shadowRadius = 3 * unit
        }

        let maxWidth = renderSize.width * 0.9
        let measured = (caption.text as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: platformFont],
            context: nil
        ).size
        let w = min(maxWidth, ceil(measured.width) + 16 * unit)
        let h = ceil(measured.height) + 16 * unit
        // Core Animation video layers use a bottom-left origin.
        let x = renderSize.width * caption.position.x - w / 2
        let y = renderSize.height * caption.position.y - h / 2
        layer.frame = CGRect(x: x, y: y, width: w, height: h)
        return layer
    }

    // MARK: - Color helpers

    private static func cgColor(hex: String) -> CGColor {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8) & 0xFF) / 255
        let b = CGFloat(rgb & 0xFF) / 255
        return CGColor(red: r, green: g, blue: b, alpha: 1)
    }

    private static func platformColor(hex: String) -> Any {
        #if canImport(UIKit)
        return UIColor(cgColor: cgColor(hex: hex))
        #elseif canImport(AppKit)
        return NSColor(cgColor: cgColor(hex: hex)) ?? NSColor.white
        #endif
    }
}
