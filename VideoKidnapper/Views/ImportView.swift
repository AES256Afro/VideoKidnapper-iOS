import PhotosUI
import SwiftUI

struct ImportView: View {
    @EnvironmentObject var store: VideoProjectStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Start with a video")
                .font(.title2)
                .bold()

            Text("Pick a clip from your photo library. Everything stays on this device — nothing is uploaded.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            PhotosPicker(selection: $pickerItem, matching: .videos) {
                Label("Choose a video", systemImage: "photo.on.rectangle")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if isLoading {
                ProgressView("Loading video…")
            }

            if let message = store.exportMessage {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await load(newItem) }
        }
    }

    @MainActor
    private func load(_ item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let movie = try await item.loadTransferable(type: MovieFile.self) {
                await store.load(url: movie.url)
            } else {
                store.exportMessage = "Couldn't load that video."
            }
        } catch {
            store.exportMessage = "Couldn't load that video: \(error.localizedDescription)"
        }
        pickerItem = nil
    }
}
