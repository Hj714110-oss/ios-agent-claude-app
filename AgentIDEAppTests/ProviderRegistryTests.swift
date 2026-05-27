import XCTest
@testable import AgentIDEApp

final class ProviderRegistryTests: XCTestCase {
    func testDefaultRegistryHasActiveProfile() {
        let registry = ProviderRegistry.default
        XCTAssertFalse(registry.profiles.isEmpty)
        XCTAssertTrue(registry.profiles.contains(where: { $0.id == registry.activeProfileId }))
    }

    func testProviderProfileRoundTripCodable() throws {
        let profile = ProviderProfile.makeDefault(id: "p1", name: "A")
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(ProviderProfile.self, from: data)
        XCTAssertEqual(decoded.id, "p1")
        XCTAssertEqual(decoded.name, "A")
    }
}
