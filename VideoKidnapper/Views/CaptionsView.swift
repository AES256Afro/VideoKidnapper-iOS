import SwiftUI

struct CaptionsView: View {
    @EnvironmentObject var store: VideoProjectStore
    @State private var editingID: UUID?

    var body: some View {
        Group {
            if store.captions.isEmpty {
                ContentUnavailableView(
                    "No captions yet",
                    systemImage: "captions.bubble",
                    description: Text("Add captions and style them — they'll be burned into the export exactly as shown.")
                )
            } else {
                List {
                    ForEach($store.captions) { $caption in
                        Button {
                            editingID = caption.id
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(caption.text)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(formatTime(caption.start)) – \(formatTime(caption.end))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.captions.removeAll { $0.id == caption.id }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .toolbar {
            Button("Add caption", systemImage: "plus") {
                let start = store.trimStart
                let end = min(store.trimStart + 3, store.trimEnd)
                var caption = Caption()
                caption.start = start
                caption.end = max(end, start + 0.5)
                store.captions.append(caption)
                editingID = caption.id
            }
        }
        .sheet(item: Binding(
            get: { editingID.flatMap { id in store.captions.first(where: { $0.id == id }) } },
            set: { editingID = $0?.id }
        )) { caption in
            if let index = store.captions.firstIndex(where: { $0.id == caption.id }) {
                CaptionEditor(caption: $store.captions[index], duration: store.duration)
            }
        }
    }
}

struct CaptionEditor: View {
    @Binding var caption: Caption
    var duration: Double
    @Environment(\.dismiss) private var dismiss
    @State private var textColor = Color.white
    @State private var outlineColor = Color.black

    var body: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    TextField("Caption text", text: $caption.text, axis: .vertical)
                        .lineLimit(3...)
                }
                Section("Timing") {
                    HStack {
                        Text("Start")
                        Slider(value: $caption.start, in: 0...duration)
                        Text(formatTime(caption.start)).font(.caption.monospacedDigit())
                    }
                    HStack {
                        Text("End")
                        Slider(value: $caption.end, in: 0...duration)
                        Text(formatTime(caption.end)).font(.caption.monospacedDigit())
                    }
                }
                Section("Style") {
                    HStack {
                        Text("Size")
                        Slider(value: $caption.style.fontSize, in: 24...120)
                    }
                    Toggle("Bold", isOn: $caption.style.isBold)
                    Toggle("Drop shadow", isOn: $caption.style.shadowEnabled)
                    ColorPicker("Text color", selection: $textColor)
                    ColorPicker("Outline color", selection: $outlineColor)
                    HStack {
                        Text("Outline")
                        Slider(value: $caption.style.outlineWidth, in: 0...12)
                    }
                }
                Section("Position") {
                    Text("Drag on the preview in a future update — for now, vertical placement:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("Height")
                        Slider(value: $caption.position.y, in: 0.05...0.95)
                    }
                }
                Section {
                    // Live preview of the styled caption.
                    Text(caption.text.isEmpty ? "Preview" : caption.text)
                        .font(.system(size: 28, weight: caption.style.isBold ? .bold : .regular))
                        .foregroundStyle(textColor)
                        .shadow(color: .black.opacity(caption.style.shadowEnabled ? 0.6 : 0), radius: 3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                        .background(Color.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Edit caption")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                Button("Done") { dismiss() }
            }
            .onAppear {
                textColor = Color(hex: caption.style.textColorHex)
                outlineColor = Color(hex: caption.style.outlineColorHex)
            }
            .onChange(of: textColor) { _, new in caption.style.textColorHex = hexString(for: new) }
            .onChange(of: outlineColor) { _, new in caption.style.outlineColorHex = hexString(for: new) }
        }
    }
}
