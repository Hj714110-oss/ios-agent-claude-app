import XCTest
@testable import AgentIDEApp

final class WorkspaceWriteServiceTests: XCTestCase {
    func testRejectsPathTraversal() throws {
        let service = WorkspaceWriteServiceImpl()
        let root = NSTemporaryDirectory()
        XCTAssertThrowsError(
            try service.previewWrite(root: root, targetPath: "../escape.swift", newContent: "x")
        )
    }

    func testApplyAndRollback() throws {
        let service = WorkspaceWriteServiceImpl()
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let target = "main.py"
        let old = "print('old')\n"
        let targetURL = rootURL.appendingPathComponent(target)
        try old.write(to: targetURL, atomically: true, encoding: .utf8)

        let preview = try service.previewWrite(root: rootURL.path, targetPath: target, newContent: "print('new')\n")
        try service.applyWrite(root: rootURL.path, preview: preview)
        let afterApply = try String(contentsOf: targetURL, encoding: .utf8)
        XCTAssertEqual(afterApply, "print('new')\n")

        try service.rollbackLast()
        let afterRollback = try String(contentsOf: targetURL, encoding: .utf8)
        XCTAssertEqual(afterRollback, old)
    }
}
