import Foundation

@MainActor
final class NetworkingService: NSObject, URLSessionTaskDelegate, URLSessionDelegate {
    static let shared = NetworkingService()
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.liurui.icost.bg")
        config.waitsForConnectivity = true
        config.isDiscretionary = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    var onProgress: ((Double) -> Void)?
    var onCompleted: ((Result<Data, Error>) -> Void)?

    private struct UploadJob { let fileURL: URL; let endpoint: URL; let maxRetries: Int }
    private var jobs: [Int: UploadJob] = [:]
    private var attempts: [Int: Int] = [:]

    override init() { super.init() }

    func upload(url: URL, to endpoint: URL, maxRetries: Int = 3) {
        startUpload(fileURL: url, endpoint: endpoint, maxRetries: maxRetries)
    }

    private func startUpload(fileURL: URL, endpoint: URL, maxRetries: Int) {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        let task = session.uploadTask(with: request, fromFile: fileURL)
        jobs[task.taskIdentifier] = UploadJob(fileURL: fileURL, endpoint: endpoint, maxRetries: maxRetries)
        attempts[task.taskIdentifier] = (attempts[task.taskIdentifier] ?? 0) + 1
        task.resume()
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            let id = task.taskIdentifier
            if let error = error {
                if let job = self.jobs[id], let attempt = self.attempts[id], attempt < job.maxRetries {
                    let delay = pow(2.0, Double(attempt)) * 0.5
                    self.jobs[id] = nil
                    self.attempts[id] = nil
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    self.startUpload(fileURL: job.fileURL, endpoint: job.endpoint, maxRetries: job.maxRetries)
                    return
                }
                self.jobs[id] = nil
                self.attempts[id] = nil
                self.onCompleted?(.failure(error))
            } else {
                self.jobs[id] = nil
                self.attempts[id] = nil
                self.onCompleted?(.success(Data()))
            }
        }
    }
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        Task { @MainActor in
            if totalBytesExpectedToSend > 0 { self.onProgress?(Double(totalBytesSent) / Double(totalBytesExpectedToSend)) }
        }
    }
}
