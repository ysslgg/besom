import Foundation

/// Lance des commandes (Homebrew, mdfind, launchctl…) avec un PATH complet : une app lancée depuis le Finder n'a pas celui du terminal.
enum Shell {
    static let searchPath = ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin", "/usr/local/sbin",
                             "/usr/bin", "/bin", "/usr/sbin", "/sbin"]

    static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = searchPath.joined(separator: ":")
        env["HOMEBREW_NO_ANALYTICS"] = "1"
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["NONINTERACTIVE"] = "1"
        return env
    }

    static func which(_ name: String) -> String? {
        searchPath.map { $0 + "/" + name }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private final class Box: @unchecked Sendable { var data = Data() }

    /// Exécute une commande et renvoie sa sortie complète.
    static func run(_ exe: String, _ args: [String]) async -> (status: Int32, out: String, err: String) {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: exe)
                p.arguments = args
                p.environment = environment()
                p.standardInput = FileHandle.nullDevice
                let out = Pipe(), err = Pipe()
                p.standardOutput = out
                p.standardError = err
                do { try p.run() } catch { cont.resume(returning: (-1, "", error.localizedDescription)); return }
                // Les deux tubes sont lus en parallèle : sinon un tube plein bloquerait la commande.
                let errBox = Box()
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global().async { errBox.data = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
                let outData = out.fileHandleForReading.readDataToEndOfFile()
                group.wait()
                p.waitUntilExit()
                cont.resume(returning: (p.terminationStatus, String(decoding: outData, as: UTF8.self), String(decoding: errBox.data, as: UTF8.self)))
            }
        }
    }

    /// Exécute une commande en renvoyant sa sortie ligne par ligne, au fur et à mesure.
    static func stream(_ exe: String, _ args: [String], onLine: @escaping @Sendable (String) -> Void) async -> Int32 {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: exe)
                p.arguments = args
                p.environment = environment()
                p.standardInput = FileHandle.nullDevice
                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = pipe
                do { try p.run() } catch { onLine(error.localizedDescription); cont.resume(returning: -1); return }
                var pending = Data()
                func flush(final: Bool) {
                    while let i = pending.firstIndex(where: { $0 == 10 || $0 == 13 }) {
                        let line = String(decoding: pending[pending.startIndex..<i], as: UTF8.self)
                        pending.removeSubrange(pending.startIndex...i)
                        if !line.trimmingCharacters(in: .whitespaces).isEmpty { onLine(strip(line)) }
                    }
                    if final, !pending.isEmpty { onLine(strip(String(decoding: pending, as: UTF8.self))); pending.removeAll() }
                }
                while true {
                    let chunk = pipe.fileHandleForReading.availableData
                    if chunk.isEmpty { break }
                    pending.append(chunk)
                    flush(final: false)
                }
                flush(final: true)
                p.waitUntilExit()
                cont.resume(returning: p.terminationStatus)
            }
        }
    }

    /// Retire les séquences de couleur ANSI.
    private static func strip(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{1B}\\[[0-9;]*[A-Za-z]", with: "", options: .regularExpression)
    }
}
