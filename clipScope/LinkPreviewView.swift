import SwiftUI

struct LinkPreviewView: View {
    let url: URL
    @State private var preview: LinkPreview?
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let preview = preview {
                VStack(alignment: .leading, spacing: 8) {
                    if let imageUrl = preview.imageUrl,
                       let nsImage = NSImage(contentsOf: imageUrl) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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
                        .foregroundColor(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    LinkHelper.shared.openLink(url)
                }
            } else {
                Text(url.absoluteString)
                    .font(.body)
                    .foregroundColor(.accentColor)
                    .lineLimit(1)
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
        LinkHelper.shared.fetchLinkPreview(for: url) { fetchedPreview in
            preview = fetchedPreview
            isLoading = false
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