import Foundation
import CryptoKit
import PianoCore

/// This binary compiles one approved theme, not an extensible runtime theme interpreter.
/// Pin the originating bytes so a modified/missing theme cannot silently render stale styles.
public struct QuietIvoryProvenance {
    public let themeVersion = "quiet-ivory-u001.0.3"
    public let themeSHA256: String
    public let mappingSHA256: String
    public init(themeURL: URL, mappingURL: URL) throws {
        themeSHA256 = Self.digest(try Data(contentsOf: themeURL))
        mappingSHA256 = Self.digest(try Data(contentsOf: mappingURL))
        guard themeSHA256 == "1cd6ec885ff33d3cb071300c63b753604d29c5b4b28fbcdccf69812fff0220fb" else {
            throw ProbeError.invalid("Quiet Ivory主题缺失或与批准候选不符：\(themeURL.path)")
        }
        guard mappingSHA256 == "147ad9041aa7514e70e80c94a476149f47944d36f74367825ae95bd69edf245b" else {
            throw ProbeError.invalid("主题对应映射不符：\(mappingURL.path)，须批准后重新适配")
        }
    }
    public static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public var metadata: [String: Any] {
        let binaryHash = (try? Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[0]))).map(Self.digest) ?? "unavailable"
        return ["themeVersion": themeVersion, "themeSHA256": themeSHA256, "mappingSHA256": mappingSHA256,
         "artifactState": "design_proposal", "integrationBuild": "C-001C", "executableSHA256": binaryHash, "OS": ProcessInfo.processInfo.operatingSystemVersionString,
         "hardwareInput": false, "hardwareAudio": false, "systemDockWrites": false]
    }
}
