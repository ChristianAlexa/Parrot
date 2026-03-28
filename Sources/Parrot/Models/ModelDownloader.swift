import Foundation
import os

enum DownloadState: Equatable {
    case idle
    case downloading(progress: Double, bytesWritten: Int64, totalBytes: Int64)
    case completed(URL)
    case failed(String)

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}

@Observable
@MainActor
final class ModelDownloader {
    private(set) var downloads: [String: DownloadState] = [:]

    private let logger = Logger(subsystem: "com.parrot", category: "ModelDownloader")
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    private var delegate: DownloadDelegate?
    private var session: URLSession?

    init() {
        let delegate = DownloadDelegate()
        self.delegate = delegate
        self.session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        delegate.onProgress = { [weak self] taskID, bytesWritten, totalBytes in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let progress = totalBytes > 0 ? Double(bytesWritten) / Double(totalBytes) : 0
                self.downloads[taskID] = .downloading(progress: progress, bytesWritten: bytesWritten, totalBytes: totalBytes)
            }
        }

        delegate.onComplete = { [weak self] taskID, tempURL, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.activeTasks.removeValue(forKey: taskID)

                if let error {
                    self.logger.error("Download failed for \(taskID): \(error.localizedDescription)")
                    ActivityLog.shared.log(.error, category: "ModelDownloader", message: "Download failed for \(taskID): \(error.localizedDescription)")
                    self.downloads[taskID] = .failed(error.localizedDescription)
                    return
                }

                guard let tempURL else {
                    self.downloads[taskID] = .failed("No file received")
                    return
                }

                // Move to models directory
                do {
                    let fileName = self.pendingFileNames[taskID] ?? "\(taskID).bin"
                    self.pendingFileNames.removeValue(forKey: taskID)
                    let dest = ModelManager.modelsDirectory.appendingPathComponent(fileName)
                    let fm = FileManager.default
                    if fm.fileExists(atPath: dest.path) {
                        try fm.removeItem(at: dest)
                    }
                    try fm.moveItem(at: tempURL, to: dest)
                    self.logger.info("Download complete: \(dest.lastPathComponent)")
                    ActivityLog.shared.log(.info, category: "ModelDownloader", message: "Download complete: \(dest.lastPathComponent)")
                    self.downloads[taskID] = .completed(dest)
                    self.deleteResumeData(for: taskID)
                } catch {
                    self.logger.error("Failed to move download: \(error.localizedDescription)")
                    ActivityLog.shared.log(.error, category: "ModelDownloader", message: "Failed to move download: \(error.localizedDescription)")
                    self.downloads[taskID] = .failed(error.localizedDescription)
                }
            }
        }
    }

    private var pendingFileNames: [String: String] = [:]

    func download(_ model: RecommendedModel) {
        guard downloads[model.id]?.isDownloading != true else { return }

        ModelManager().ensureModelsDirectoryExists()
        pendingFileNames[model.id] = model.fileName
        downloads[model.id] = .downloading(progress: 0, bytesWritten: 0, totalBytes: model.expectedSizeBytes)

        // Check for resume data
        if let resumeData = loadResumeData(for: model.id) {
            let task = session!.downloadTask(withResumeData: resumeData)
            task.taskDescription = model.id
            activeTasks[model.id] = task
            task.resume()
            logger.info("Resuming download: \(model.fileName)")
            ActivityLog.shared.log(.info, category: "ModelDownloader", message: "Resuming download: \(model.fileName)")
        } else {
            let task = session!.downloadTask(with: model.downloadURL)
            task.taskDescription = model.id
            activeTasks[model.id] = task
            task.resume()
            logger.info("Starting download: \(model.fileName)")
            ActivityLog.shared.log(.info, category: "ModelDownloader", message: "Starting download: \(model.fileName)")
        }
    }

    func cancel(_ modelID: String) {
        guard let task = activeTasks[modelID] else { return }

        task.cancel { [weak self] resumeData in
            if let resumeData {
                Task { @MainActor [weak self] in
                    self?.saveResumeData(resumeData, for: modelID)
                }
            }
        }

        activeTasks.removeValue(forKey: modelID)
        downloads[modelID] = .idle
        logger.info("Download cancelled: \(modelID)")
        ActivityLog.shared.log(.info, category: "ModelDownloader", message: "Download cancelled: \(modelID)")
    }

    /// Check if a recommended model's file already exists in the models directory.
    func isModelDownloaded(_ model: RecommendedModel) -> Bool {
        let path = ModelManager.modelsDirectory.appendingPathComponent(model.fileName)
        return FileManager.default.fileExists(atPath: path.path)
    }

    func modelPath(for model: RecommendedModel) -> URL {
        ModelManager.modelsDirectory.appendingPathComponent(model.fileName)
    }

    // MARK: - Resume Data Persistence

    private func resumeDataPath(for modelID: String) -> URL {
        ModelManager.modelsDirectory.appendingPathComponent(".\(modelID).resume")
    }

    private func saveResumeData(_ data: Data, for modelID: String) {
        try? data.write(to: resumeDataPath(for: modelID))
    }

    private func loadResumeData(for modelID: String) -> Data? {
        try? Data(contentsOf: resumeDataPath(for: modelID))
    }

    private func deleteResumeData(for modelID: String) {
        try? FileManager.default.removeItem(at: resumeDataPath(for: modelID))
    }
}

// MARK: - Download Delegate

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var onProgress: ((String, Int64, Int64) -> Void)?
    var onComplete: ((String, URL?, Error?) -> Void)?

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskID = downloadTask.taskDescription ?? "unknown"

        // Copy to a temp location we control (the system will delete `location` after this method returns)
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.moveItem(at: location, to: tempFile)
            onComplete?(taskID, tempFile, nil)
        } catch {
            onComplete?(taskID, nil, error)
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let taskID = downloadTask.taskDescription ?? "unknown"
        onProgress?(taskID, totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let taskID = task.taskDescription ?? "unknown"
        // Only report if not a cancellation (cancellation is handled in cancel())
        if (error as NSError).code != NSURLErrorCancelled {
            onComplete?(taskID, nil, error)
        }
    }
}
