import Foundation
import Observation

@Observable final class ModelDownloadService {

    enum DownloadState: Equatable {
        case notStarted
        case downloading(progress: Double)
        case completed
        case failed(String)
    }

    private(set) var downloadState: DownloadState = .notStarted

    static let modelDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Models/gemma-4-E2B", isDirectory: true)
    }()

    private static let sessionIdentifier = "com.personalai.assistant.model-download"
    private static let baseURL = "https://huggingface.co/mlx-community/gemma-4-e2b-it-4bit/resolve/main"

    static let requiredFiles = [
        "config.json",
        "generation_config.json",
        "model.safetensors",
        "model.safetensors.index.json",
        "processor_config.json",
        "tokenizer.json",
        "tokenizer_config.json",
        "chat_template.jinja"
    ]

    private let sessionDelegate: BackgroundDownloadDelegate
    private var backgroundSession: URLSession!

    var isModelReady: Bool {
        Self.requiredFiles.allSatisfy {
            FileManager.default.fileExists(atPath: Self.modelDirectory.appendingPathComponent($0).path)
        }
    }

    init() {
        sessionDelegate = BackgroundDownloadDelegate()

        let config = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        backgroundSession = URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)

        sessionDelegate.onProgress = { [weak self] progress in
            self?.downloadState = .downloading(progress: progress)
        }
        sessionDelegate.onComplete = { [weak self] in
            self?.downloadState = .completed
        }
        sessionDelegate.onError = { [weak self] message in
            self?.downloadState = .failed(message)
        }

        if isModelReady {
            downloadState = .completed
        } else {
            backgroundSession.getAllTasks { [weak self] tasks in
                let active = tasks.contains { $0.state == .running || $0.state == .suspended }
                if active {
                    DispatchQueue.main.async {
                        self?.downloadState = .downloading(progress: 0)
                    }
                }
            }
        }
    }

    func startDownload() {
        guard !isModelReady else {
            downloadState = .completed
            return
        }

        try? FileManager.default.createDirectory(at: Self.modelDirectory, withIntermediateDirectories: true)
        downloadState = .downloading(progress: 0)

        for filename in Self.requiredFiles {
            let filePath = Self.modelDirectory.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: filePath.path) { continue }
            guard let url = URL(string: "\(Self.baseURL)/\(filename)") else { continue }
            let task = backgroundSession.downloadTask(with: url)
            task.resume()
        }
    }

    func setBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        sessionDelegate.backgroundCompletionHandler = handler
    }
}

private final class BackgroundDownloadDelegate: NSObject, URLSessionDownloadDelegate {

    var onProgress: ((Double) -> Void)?
    var onComplete: (() -> Void)?
    var onError: ((String) -> Void)?
    var backgroundCompletionHandler: (() -> Void)?

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let filename = downloadTask.originalRequest?.url?.lastPathComponent else { return }
        let destination = ModelDownloadService.modelDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            DispatchQueue.main.async { self.onError?("Failed to save \(filename)") }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let filename = downloadTask.originalRequest?.url?.lastPathComponent else { return }
        if filename == "model.safetensors" {
            let progress = Double(totalBytesWritten) / Double(max(totalBytesExpectedToWrite, 1))
            DispatchQueue.main.async { self.onProgress?(min(progress, 0.99)) }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            DispatchQueue.main.async { self.onError?(error.localizedDescription) }
            return
        }
        let allPresent = ModelDownloadService.requiredFiles.allSatisfy {
            FileManager.default.fileExists(
                atPath: ModelDownloadService.modelDirectory.appendingPathComponent($0).path
            )
        }
        if allPresent {
            DispatchQueue.main.async { self.onComplete?() }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
}
