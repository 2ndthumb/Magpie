import SwiftUI

struct LinkPreviewView: View {
    let url: URL
    @State private var preview: LinkPreview?
    @State private var isLoading = false
    @State private var loadingError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let preview = preview {
                VStack(alignment: .leading, spacing: 8) {
                    if let imageUrl = preview.imageUrl {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            case .failure(_):
                                EmptyView()
                            case .empty:
                                EmptyView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    
                    Text(preview.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if !preview.description.isEmpty {
                        Text(preview.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    
                    Text(preview.url.host ?? preview.url.absoluteString)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    LinkHelper.shared.openLink(url)
                }
            } else {
                HStack {
                    Text(url.absoluteString)
                        .font(.body)
                        .foregroundColor(.accentColor)
                        .lineLimit(1)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 16, height: 16)
                    }
                }
                .onTapGesture {
                    LinkHelper.shared.openLink(url)
                }
            }
        }
        .onAppear {
            loadPreview()
        }
    }
    
    private func loadPreview() {
        isLoading = true
        loadingError = false
        
        LinkHelper.shared.fetchLinkPreview(for: url) { fetchedPreview in
            isLoading = false
            if let fetchedPreview = fetchedPreview {
                preview = fetchedPreview
            } else {
                loadingError = true
            }
        }
    }
}

struct LinkPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        LinkPreviewView(url: URL(string: "https://www.apple.com")!)
            .frame(width: 300)
            .padding()
    }
} 