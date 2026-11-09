import XCTest

final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    @MainActor private func capture(_ scenario: String, label: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshot", scenario]
        app.launch()
        XCTAssertTrue(app.staticTexts[label].firstMatch.waitForExistence(timeout: 20), "Expected the real \(scenario) screen, not setup or loading")
        if scenario == "parent" { XCTAssertTrue(app.buttons["Send"].exists) }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "FEED-CONNOR-\(scenario.uppercased())-sample-data"
        attachment.lifetime = .keepAlways
        add(attachment)
        if scenario == "gift" {
            app.buttons["Open gift"].tap()
            XCTAssertTrue(app.buttons["Eat"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Later"].exists)
            let interaction = XCTAttachment(screenshot: app.screenshot())
            interaction.name = "FEED-CONNOR-EAT-LATER-sample-data"
            interaction.lifetime = .keepAlways
            add(interaction)
        }
        app.terminate()
    }
    @MainActor func testFed() { capture("fed", label: "FED") }
    @MainActor func testHungry() { capture("hungry", label: "HUNGRY") }
    @MainActor func testTired() { capture("tired", label: "TIRED") }
    @MainActor func testGift() { capture("gift", label: "GIFT") }
    @MainActor func testParent() { capture("parent", label: "GIFT") }
    @MainActor private func captureWidget(_ mood: String, size: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshot", "widget-\(size)-\(mood)"]
        app.launch()
        let label = app.staticTexts["widgetSelection"]
        XCTAssertTrue(label.waitForExistence(timeout: 20))
        XCTAssertEqual(label.label, "\(mood.uppercased()) · \(size.uppercased())")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "widgetPreview").firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "FEED-CONNOR-WIDGET-PREVIEW-\(size.uppercased())-\(mood.uppercased())"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }
    @MainActor func testWidgetSmallFed() { captureWidget("fed", size: "small") }
    @MainActor func testWidgetSmallHungry() { captureWidget("hungry", size: "small") }
    @MainActor func testWidgetSmallTired() { captureWidget("tired", size: "small") }
    @MainActor func testWidgetSmallGift() { captureWidget("gift", size: "small") }
    @MainActor func testWidgetMediumFed() { captureWidget("fed", size: "medium") }
    @MainActor func testWidgetMediumHungry() { captureWidget("hungry", size: "medium") }
    @MainActor func testWidgetMediumTired() { captureWidget("tired", size: "medium") }
    @MainActor func testWidgetMediumGift() { captureWidget("gift", size: "medium") }

}
