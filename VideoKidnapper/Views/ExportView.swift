import AVFoundation
import SwiftUI

struct ExportView: View {
    @EnvironmentObject var store: VideoProjectStore

    var body: some View {
        Form {
            Section("Output") {
                Picker("Format", selection: $store.format) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Framing", selection: $store.aspect) {
                    ForEach(AspectPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    Task { await doExport() }
                } label: {
                    HStack {
                        Spacer()
                        Text(store.isExporting ? "Exporting…" : "Export")
                            .bold()
                        Spacer()
                    }
                }
                .disabled(store.isExporting || !store.hasVideo)

                if store.isExporting {
                    ProgressView(value: store.exportProgress)
                }
                if let message = store.exportMessage {
                    Text(message)
                        .font(.callout)
                }
            }

            if let url = store.lastExportURL {
                Section("Done") {
                    ShareLink(item: url, preview: SharePreview("VideoKidnapper export", image: Image(systemName: "film")))
                    Button("Save to Photo Library", systemImage: "square.and.arrow.down") {
                        Task { await saveToLibrary(url) }
                    }
                }
            }
        }
    }

    private var summary: String {
        let range = "\(formatTime(store.trimStart))–\(formatTime(store.trimEnd))"
        let caps = store.captions.isEmpty ? "no captions" : "\(store.captions.count) caption\(store.captions.count == 1 ? "" : "s")"
        return "Exports \(range) (\(caps)) as \(store.format.displayName), \(store.aspect.displayName.lowercased())."
    }

    @MainActor
    private func doExport() async {
        guard let sourceURL = store.sourceURL else { return }
        store.isExporting = true
        store.exportProgress = 0
        store.exportMessage = nil
        store.lastExportURL = nil
        defer { store.isExporting = false }

        do {
            let asset = AVURLAsset(url: sourceURL)
            let composed = try await VideoCompositor.compose(
                source: asset,
                trimStart: store.trimStart,
                trimEnd: store.trimEnd,
                captions: store.captions,
                aspect: store.aspect
            )
            let output: URL
            switch store.format {
            case .mp4:
                output = try await VideoExporter.exportMP4(composed: composed) { p in
                    store.exportProgress = p
                }
            case .gif:
                output = try await VideoExporter.exportGIF(composed: composed) { p in
                    store.exportProgress = p
                }
            }
            store.lastExportURL = output
            store.exportMessage = "Export finished."
        } catch {
            store.exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func saveToLibrary(_ url: URL) async {
        do {
            try await VideoExporter.saveToPhotoLibrary(fileURL: url, isVideo: store.format == .mp4)
            store.exportMessage = "Saved to your photo library."
        } catch {
            store.exportMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }
}
