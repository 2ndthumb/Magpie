import Foundation
import AppKit

class LinkHelper {
    static let shared = LinkHelper()
    
    private let urlDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    
    func findLinks(in text: String) -> [URL] {
        guard let detector = urlDetector else { return [] }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.compactMap { $0.url }
    }
    
    func extractFirstLink(from text: String) -> URL? {
        guard let detector = urlDetector else { return nil }
        guard let match = detector.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) else {
            return nil
        }
        return match.url
    }
    
    func openLink(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    func fetchLinkPreview(for url: URL, completion: @escaping (LinkPreview?) -> Void) {
        let session = URLSession.shared
        let task = session.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let preview = self.parseLinkPreview(html: html, url: url)
            DispatchQueue.main.async {
                completion(preview)
            }
        }
        task.resume()
    }
    
    private func parseLinkPreview(html: String, url: URL) -> LinkPreview {
        var title = ""
        var description = ""
        var imageUrl: URL?
        
        // Extract title
        if let titleRange = html.range(of: "<title>.*?</title>", options: .regularExpression) {
            title = String(html[titleRange])
                .replacingOccurrences(of: "<title>", with: "")
                .replacingOccurrences(of: "</title>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract meta description
        if let descRange = html.range(of: "<meta\\s+name=[\"']description[\"']\\s+content=[\"'](.*?)[\"']", options: .regularExpression) {
            let desc = String(html[descRange])
            if let content = desc.range(of: "content=[\"'](.*?)[\"']", options: .regularExpression) {
                description = String(desc[content])
                    .replacingOccurrences(of: "content=", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Extract og:image
        if let imgRange = html.range(of: "<meta\\s+property=[\"']og:image[\"']\\s+content=[\"'](.*?)[\"']", options: .regularExpression) {
            let img = String(html[imgRange])
            if let content = img.range(of: "content=[\"'](.*?)[\"']", options: .regularExpression) {
                let imgUrlString = String(img[content])
                    .replacingOccurrences(of: "content=", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                imageUrl = URL(string: imgUrlString)
            }
        }
        
        return LinkPreview(
            url: url,
            title: title.isEmpty ? url.host ?? url.absoluteString : title,
            description: description,
            imageUrl: imageUrl
        )
    }
}

struct LinkPreview: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let description: String
    let imageUrl: URL?
} 