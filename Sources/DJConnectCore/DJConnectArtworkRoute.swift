import Foundation

/// Public HA image-proxy URLs follow the confirmed HA transport. Third-party
/// artwork and credentialed Session grants never get rewritten by this helper.
public enum DJConnectArtworkRoute {
    public static func resolve(_ artwork: URL?, knownOrigins: [URL], preferredOrigin: URL?) -> URL? {
        guard let artwork else { return nil }
        if artwork.scheme == nil {
            guard artwork.host == nil else { return nil }
            guard let base = preferredOrigin ?? knownOrigins.first else { return artwork }
            return URL(string: artwork.relativeString, relativeTo: base)?.absoluteURL
        }
        guard ["http", "https"].contains(artwork.scheme?.lowercased() ?? ""),
              artwork.user == nil, artwork.password == nil else { return nil }
        guard artwork.path.hasPrefix("/api/djconnect/v1/image_proxy/"),
              knownOrigins.contains(where: { sameOrigin($0, artwork) }),
              let preferredOrigin, knownOrigins.contains(where: { sameOrigin($0, preferredOrigin) }),
              preferredOrigin.user == nil, preferredOrigin.password == nil,
              var components = URLComponents(url: artwork, resolvingAgainstBaseURL: false) else { return artwork }
        components.scheme = preferredOrigin.scheme
        components.host = preferredOrigin.host
        components.port = preferredOrigin.port
        return components.url
    }
    private static func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        func port(_ url: URL) -> Int? { url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80) }
        return lhs.scheme?.lowercased() == rhs.scheme?.lowercased() &&
            lhs.host?.lowercased() == rhs.host?.lowercased() && port(lhs) == port(rhs)
    }
}
