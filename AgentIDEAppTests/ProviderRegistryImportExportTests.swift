import XCTest
@testable import AgentIDEApp

final class ProviderRegistryImportExportTests: XCTestCase {
    func testRegistryExportImportRoundTrip() throws {
        let p1 = ProviderProfile.makeDefault(id: "a", name: "A")
        let p2 = ProviderProfile.makeDefault(id: "b", name: "B")
        let registry = ProviderRegistry(profiles: [p1, p2], activeProfileId: "b")
        let data = try JSONEncoder().encode(registry)
        let decoded = try JSONDecoder().decode(ProviderRegistry.self, from: data)
        XCTAssertEqual(decoded.profiles.count, 2)
        XCTAssertEqual(decoded.activeProfileId, "b")
    }
}
