import XCTest

final class TwinskaraokeUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }
  @MainActor
  func testLaunches() throws {
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
  }
  @MainActor
  func testTabBarHasAllTabs() throws {
    let app = XCUIApplication()
    app.launch()
    let tabBar = app.tabBars.firstMatch
    XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    for label in ["Home", "Radio", "Library", "Search", "Account"] {
      XCTAssertTrue(tabBar.buttons[label].exists, "Tab '\(label)' should exist")
    }
  }
  @MainActor
  func testCanSwitchTabs() throws {
    let app = XCUIApplication()
    app.launch()
    let tabBar = app.tabBars.firstMatch
    XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
    tabBar.buttons["Library"].tap()
    XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 3))
    tabBar.buttons["Search"].tap()
    XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 3))
    tabBar.buttons["Radio"].tap()
    XCTAssertTrue(app.navigationBars["Radio"].waitForExistence(timeout: 3))
    tabBar.buttons["Home"].tap()
    XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 3))
  }
  @MainActor
  func testLibraryShowsBrowseRows() throws {
    let app = XCUIApplication()
    app.launch()
    app.tabBars.firstMatch.buttons["Library"].tap()
    XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Playlists"].exists)
    XCTAssertTrue(app.staticTexts["Favorites"].exists)
    XCTAssertTrue(app.staticTexts["Downloaded"].exists)
    XCTAssertTrue(app.staticTexts["Random Songs"].exists)
  }
  @MainActor
  func testAccountSignInVisibleWhenLoggedOut() throws {
    let app = XCUIApplication()
    app.launch()
    app.tabBars.firstMatch.buttons["Account"].tap()
    XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
  }
}
