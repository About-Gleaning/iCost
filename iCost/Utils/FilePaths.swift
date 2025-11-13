import Foundation

enum FilePaths {
    static func audioDirectory() -> URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func audioFileURL() -> URL {
        audioDirectory().appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
    }
}
