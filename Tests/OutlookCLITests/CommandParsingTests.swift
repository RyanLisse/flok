import XCTest
@testable import OutlookCLI
import ArgumentParser

final class CommandParsingTests: XCTestCase {
    func testOutlookCommandExists() {
        // Verify the root command is properly configured
        XCTAssertEqual(OutlookCommand.configuration.commandName, "outlook")
        XCTAssertFalse(OutlookCommand.configuration.abstract.isEmpty)
    }

    func testSubcommandsRegistered() {
        let subcommands = OutlookCommand.configuration.subcommands
        let names = subcommands.map { $0.configuration.commandName ?? "" }
        XCTAssertTrue(names.contains("auth"), "Should have auth subcommand")
        XCTAssertTrue(names.contains("mail"), "Should have mail subcommand")
        XCTAssertTrue(names.contains("cal"), "Should have cal subcommand")
    }

    func testVersionDefined() {
        XCTAssertNotNil(OutlookCommand.configuration.version)
        XCTAssertFalse(OutlookCommand.configuration.version!.isEmpty)
    }
}
