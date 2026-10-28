import Foundation
import AppKit

/// Vérifie sur GitHub si une version plus récente de Besom existe (une requête, au plus une fois par jour en automatique).
@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    enum State: Equatable {
        case idle, checking, upToDate
        case available(version: String, url: URL)
        case failed
    }

    @Published private(set) var state: State = .idle

    static let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    private let api = URL(string: "https://api.github.com/repos/ysslgg/besom/releases/latest")!
    private let releases = URL(string: "https://github.com/ysslgg/besom/releases/latest")!

    var availableVersion: String? {
        if case .available(let v, _) = state { return v }
        return nil
    }

    /// Au lancement : au plus une vérification par 24 h.
    func checkIfDue() {
        let last = UserDefaults.standard.double(forKey: "lastUpdateCheck")
        guard Date().timeIntervalSince1970 - last > 86_400 else { return }
        check()
    }

    func check() {
        guard state != .checking else { return }
        state = .checking
        var request = URLRequest(url: api, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            var tag: String?
            var page: URL?
            if let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                tag = json["tag_name"] as? String
                page = (json["html_url"] as? String).flatMap(URL.init(string:))
            }
            DispatchQueue.main.async { [self] in
                guard let tag else { state = .failed; return }
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastUpdateCheck")
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                state = latest.compare(Self.current, options: .numeric) == .orderedDescending
                    ? .available(version: latest, url: page ?? releases) : .upToDate
            }
        }.resume()
    }

    func openDownload() {
        if case .available(_, let url) = state { NSWorkspace.shared.open(url) }
    }
}
