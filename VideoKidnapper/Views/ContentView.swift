import SwiftUI

enum EditStep: String, CaseIterable, Identifiable {
    case importStep = "Import"
    case trim = "Trim"
    case captions = "Captions"
    case export = "Export"

    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject var store: VideoProjectStore
    @State private var step: EditStep = .importStep

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Step", selection: $step) {
                    ForEach(EditStep.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Group {
                    if !store.hasVideo {
                        ImportView()
                    } else {
                        switch step {
                        case .importStep: ImportView()
                        case .trim: TrimView()
                        case .captions: CaptionsView()
                        case .export: ExportView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("VideoKidnapper")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if store.hasVideo {
                    Button("New video", systemImage: "plus") {
                        store.reset()
                        step = .importStep
                    }
                }
            }
        }
    }
}
