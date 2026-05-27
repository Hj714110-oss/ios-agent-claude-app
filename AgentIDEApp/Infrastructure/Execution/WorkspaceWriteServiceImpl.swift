import Foundation

enum WorkspaceWriteError: LocalizedError {
    case invalidRoot
    case invalidTargetPath
    case outOfWorkspace
    case emptyTargetPath
    case noRollbackSnapshot

    var errorDescription: String? {
        switch self {
        case .invalidRoot:
            return "Workspace root is invalid."
        case .invalidTargetPath:
            return "Target path is invalid."
        case .outOfWorkspace:
            return "Target path is outside workspace root."
        case .emptyTargetPath:
            return "Target path cannot be empty."
        case .noRollbackSnapshot:
            return "No rollback snapshot available."
        }
    }
}

final class WorkspaceWriteServiceImpl: WorkspaceWriteService {
    private let fileManager: FileManager
    private var lastSnapshot: (path: URL, oldContent: String)?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func previewWrite(root: String, targetPath: String, newContent: String) throws -> WritePreview {
        let targetURL = try resolveTarget(root: root, targetPath: targetPath)
        let oldContent = (try? String(contentsOf: targetURL, encoding: .utf8)) ?? ""
        let changedLines = Self.changedLineCount(old: oldContent, new: newContent)
        return WritePreview(
            id: UUID(),
            targetPath: targetPath,
            oldContent: oldContent,
            newContent: newContent,
            changedLineCount: changedLines
        )
    }

    func applyWrite(root: String, preview: WritePreview) throws {
        let targetURL = try resolveTarget(root: root, targetPath: preview.targetPath)
        let current = (try? String(contentsOf: targetURL, encoding: .utf8)) ?? ""
        lastSnapshot = (path: targetURL, oldContent: current)

        let dir = targetURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        try preview.newContent.write(to: targetURL, atomically: true, encoding: .utf8)
    }

    func rollbackLast() throws {
        guard let snapshot = lastSnapshot else {
            throw WorkspaceWriteError.noRollbackSnapshot
        }
        try snapshot.oldContent.write(to: snapshot.path, atomically: true, encoding: .utf8)
        lastSnapshot = nil
    }

    private func resolveTarget(root: String, targetPath: String) throws -> URL {
        let trimmedRoot = root.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRoot.isEmpty else { throw WorkspaceWriteError.invalidRoot }
        let trimmedTarget = targetPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty else { throw WorkspaceWriteError.emptyTargetPath }
        guard !trimmedTarget.contains("..") else { throw WorkspaceWriteError.invalidTargetPath }

        let rootURL = URL(fileURLWithPath: trimmedRoot).standardizedFileURL
        let targetURL = rootURL.appendingPathComponent(trimmedTarget).standardizedFileURL
        guard targetURL.path.hasPrefix(rootURL.path) else { throw WorkspaceWriteError.outOfWorkspace }
        return targetURL
    }

    private static func changedLineCount(old: String, new: String) -> Int {
        let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false)
        let newLines = new.split(separator: "\n", omittingEmptySubsequences: false)
        let maxCount = max(oldLines.count, newLines.count)
        var changed = 0
        for index in 0..<maxCount {
            let oldLine = index < oldLines.count ? String(oldLines[index]) : nil
            let newLine = index < newLines.count ? String(newLines[index]) : nil
            if oldLine != newLine {
                changed += 1
            }
        }
        return changed
    }
}
