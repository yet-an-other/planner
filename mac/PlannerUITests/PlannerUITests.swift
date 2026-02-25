import XCTest

final class PlannerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunchesAndShowsCalendarHeader() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Mon"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Sign in"].waitForExistence(timeout: 10))

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "launch-screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
