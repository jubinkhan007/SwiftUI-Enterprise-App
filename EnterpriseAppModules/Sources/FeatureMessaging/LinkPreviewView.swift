import SwiftUI
import LinkPresentation

#if os(iOS)
import UIKit
#endif

@MainActor
final class LinkPreviewStore: ObservableObject {
    static let shared = LinkPreviewStore()
    private var cache: [URL: LPLinkMetadata] = [:]
    
    @Published var metadata: [URL: LPLinkMetadata] = [:]
    private var loadingURLs = Set<URL>()
    
    func fetchMetadata(for url: URL) {
        if cache[url] != nil || loadingURLs.contains(url) { return }
        loadingURLs.insert(url)
        
        let provider = LPMetadataProvider()
        Task {
            do {
                let meta = try await provider.startFetchingMetadata(for: url)
                cache[url] = meta
                metadata[url] = meta
            } catch {
                // Keep quiet on errors
            }
            loadingURLs.remove(url)
        }
    }
}

#if os(iOS)
struct NativeLinkPreview: UIViewRepresentable {
    let metadata: LPLinkMetadata
    
    func makeUIView(context: Context) -> LPLinkView {
        let view = LPLinkView(metadata: metadata)
        return view
    }
    
    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}
#endif

struct LinkPreviewCard: View {
    let url: URL
    @ObservedObject private var store = LinkPreviewStore.shared
    
    var body: some View {
        Group {
            #if os(iOS)
            if let meta = store.metadata[url] {
                NativeLinkPreview(metadata: meta)
                    .frame(height: 120)
            } else {
                loadingView
            }
            #else
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundColor(.blue)
                Text(url.absoluteString)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
            .padding(10)
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
            #endif
        }
    }
    
    private var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Loading link preview...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
        .onAppear {
            store.fetchMetadata(for: url)
        }
    }
}
