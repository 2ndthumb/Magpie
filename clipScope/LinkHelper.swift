import Foundation
import AppKit

class LinkHelper {
    static let shared = LinkHelper()
    
    private let urlDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    private let timeout: TimeInterval = 10
    
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
        var request = URLRequest(url: url, timeoutInterval: timeout)
        // Set a user agent to avoid being blocked by some sites
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let data = data,
                  let html = String(data: data, encoding: .utf8),
                  error == nil else {
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
        
        // Helper function to decode HTML entities
        func decodeHTMLEntities(_ string: String) -> String {
            guard let data = string.data(using: .utf8) else { return string }
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ]
            
            if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
                return attributedString.string
            }
            return string
        }
        
        // Helper function to resolve relative URLs
        func resolveRelativeUrl(_ urlString: String) -> URL? {
            if let absolute = URL(string: urlString) {
                return absolute
            }
            return URL(string: urlString, relativeTo: url)
        }
        
        // Extract Open Graph and meta tags
        let metaPatterns = [
            "title": [
                "<meta\\s+property=[\"']og:title[\"']\\s+content=[\"'](.*?)[\"']",
                "<title>(.*?)</title>"
            ],
            "description": [
                "<meta\\s+property=[\"']og:description[\"']\\s+content=[\"'](.*?)[\"']",
                "<meta\\s+name=[\"']description[\"']\\s+content=[\"'](.*?)[\"']"
            ],
            "image": [
                "<meta\\s+property=[\"']og:image[\"']\\s+content=[\"'](.*?)[\"']",
                "<meta\\s+property=[\"']twitter:image[\"']\\s+content=[\"'](.*?)[\"']"
            ]
        ]
        
        for (key, patterns) in metaPatterns {
            for pattern in patterns {
                if let range = html.range(of: pattern, options: .regularExpression) {
                    let match = String(html[range])
                    if let contentRange = match.range(of: "content=[\"'](.*?)[\"']", options: .regularExpression) ?? 
                                        match.range(of: "<title>(.*?)</title>", options: .regularExpression) {
                        let content = String(match[contentRange])
                            .replacingOccurrences(of: "content=", with: "")
                            .replacingOccurrences(of: "<title>", with: "")
                            .replacingOccurrences(of: "</title>", with: "")
                            .replacingOccurrences(of: "\"", with: "")
                            .replacingOccurrences(of: "'", with: "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        let decodedContent = decodeHTMLEntities(content)
                        
                        switch key {
                        case "title":
                            if title.isEmpty {
                                title = decodedContent
                            }
                        case "description":
                            if description.isEmpty {
                                description = decodedContent
                            }
                        case "image":
                            if imageUrl == nil, let resolvedUrl = resolveRelativeUrl(decodedContent) {
                                imageUrl = resolvedUrl
                            }
                        default:
                            break
                        }
                    }
                }
            }
        }
        
        // Fallback to basic title if nothing was found
        if title.isEmpty {
            title = url.host ?? url.absoluteString
        }
        
        return LinkPreview(
            url: url,
            title: title,
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