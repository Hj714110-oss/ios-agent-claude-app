import Foundation

final class GeneratedAppWriterImpl: GeneratedAppWriter {
    private let writeService: WorkspaceWriteService

    init(writeService: WorkspaceWriteService) {
        self.writeService = writeService
    }

    func generate(
        workspaceRoot: String,
        appName: String,
        artifacts: [StudioArtifact]
    ) -> GeneratedAppSummary {
        let safeName = sanitizeAppName(appName)
        let base = "GeneratedApps/\(safeName)"
        var attempted = 0
        var applied = 0
        var failed = 0

        for artifact in artifacts {
            guard let targetPath = artifact.targetPath?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !targetPath.isEmpty else {
                continue
            }
            attempted += 1
            let fullPath = "\(base)/\(targetPath)"
            do {
                let preview = try writeService.previewWrite(
                    root: workspaceRoot,
                    targetPath: fullPath,
                    newContent: artifact.content
                )
                try writeService.applyWrite(root: workspaceRoot, preview: preview)
                applied += 1
            } catch {
                failed += 1
            }
        }

        return GeneratedAppSummary(
            appName: safeName,
            outputPath: "\(workspaceRoot)/\(base)",
            attemptedFiles: attempted,
            appliedFiles: applied,
            failedFiles: failed
        )
    }

    private func sanitizeAppName(_ appName: String) -> String {
        let trimmed = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "App-\(Int(Date().timeIntervalSince1970))" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let filtered = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let result = String(filtered)
        return result.isEmpty ? "App-\(Int(Date().timeIntervalSince1970))" : result
    }
}
