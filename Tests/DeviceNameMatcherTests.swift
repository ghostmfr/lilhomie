import XCTest
@testable import DeviceNameMatching

final class DeviceNameMatcherTests: XCTestCase {
    func testMatchesCaseInsensitivePartialWords() {
        XCTAssertTrue(deviceNameMatches(query: "BED READ", candidate: "Bedroom Reading Lamp"))
    }

    func testRejectsWordsThatDoNotAllMatch() {
        XCTAssertFalse(deviceNameMatches(query: "bed fan", candidate: "Bedroom Reading Lamp"))
    }

    func testClosestDeviceNameToleratesTypo() {
        let closest = closestDeviceName(
            to: "bedrom lamp",
            in: ["Kitchen Fan", "Bedroom Lamp", "Office Sconce"]
        )
        XCTAssertEqual(closest, "Bedroom Lamp")
    }

    func testClosestDeviceNameIsNilForEmptyCatalogue() {
        XCTAssertNil(closestDeviceName(to: "lamp", in: []))
    }
}
