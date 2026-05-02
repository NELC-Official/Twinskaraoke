import XCTest

final class TwinskaraokeUITestsLaunchTests: XCTestCase {
  override class var runsForEachTargetApplicationUIConfiguration: Bool { true }
  override func setUpWithError() throws {
    continueAfterFailure = false
  }
  @MainActor
  func testLaunchSnapshot() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
    attach(name: "Launch", screenshot: app.screenshot())
  }
  @MainActor
  func testHomeSnapshot() throws {
    let app = XCUIApplication()
    app.launch()
    let tabBar = app.tabBars.firstMatch
    XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    tabBar.buttons["Home"].tap()
    sleep(2)
    attach(name: "Home", screenshot: app.screenshot())
  }
  @MainActor
  func testLibrarySnapshot() throws {
    let app = XCUIApplication()
    app.launch()
    let tabBar = app.tabBars.firstMatch
    XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    tabBar.buttons["Library"].tap()
    sleep(1)
    attach(name: "Library", screenshot: app.screenshot())
  }
  @MainActor
  func testSearchSnapshot() throws {
    let app = XCUIApplication()
    app.launch()
    let tabBar = app.tabBars.firstMatch
    XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    tabBar.buttons["Search"].tap()
    sleep(1)
    attach(name: "Search", screenshot: app.screenshot())
  }
  @MainActor
  func testAccountSnapshot() throws {
    let app = XCUIApplication()
    app.launch()
    let tabBar = app.tabBars.firstMatch
    XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    tabBar.buttons["Account"].tap()
    sleep(1)
    attach(name: "Account", screenshot: app.screenshot())
  }
  @MainActor
  func testRadioSnapshot() throws {
    let app = XCUIApplication()
    app.launch()
    let tabBar = app.tabBars.firstMatch
    XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    tabBar.buttons["Radio"].tap()
    sleep(2)
    attach(name: "Radio", screenshot: app.screenshot())
  }
  private func attach(name: String, screenshot: XCUIScreenshot) {
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
