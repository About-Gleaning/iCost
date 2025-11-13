import Foundation
import Speech

@MainActor
final class SpeechService {
    func requestAuthorization(completion: @escaping @Sendable (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                completion(status == .authorized)
            }
        }
    }

    func transcribe(url: URL) async throws -> String {
        let recognizer = SFSpeechRecognizer()
        guard let recognizer = recognizer, recognizer.isAvailable else { throw NSError(domain: "Speech", code: 1) }
        let request = SFSpeechURLRecognitionRequest(url: url)
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error { continuation.resume(throwing: error); return }
                if let result = result, result.isFinal { continuation.resume(returning: result.bestTranscription.formattedString) }
            }
        }
    }
}
