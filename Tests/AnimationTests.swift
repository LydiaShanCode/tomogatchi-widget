import XCTest

final class AnimationTests: XCTestCase {
    func testHungerUsesHungryBodyWithExistingPhotoMood() {
        XCTAssertEqual(BodyAnimation.resolve(mood: .fed), .idle)
        XCTAssertEqual(BodyAnimation.resolve(mood: .hungry), .hungry)
        XCTAssertEqual(BodyAnimation.resolve(mood: .tired), .hungry)
    }
    func testDanceTemporarilyOverridesEveryMood() {
        for mood in Mood.allCases {
            XCTAssertEqual(BodyAnimation.resolve(mood: mood, dancing: true), .dancing)
            XCTAssertNotEqual(BodyAnimation.resolve(mood: mood), .dancing)
        }
    }
    func testEachAnimationCyclesThroughAllFiveFrames() {
        for animation in BodyAnimation.allCases {
            for index in 0..<5 {
                XCTAssertEqual(animation.frame(at: (Double(index) + 0.25) * animation.frameDuration), index + 1)
            }
            XCTAssertEqual(animation.frame(at: 5.25 * animation.frameDuration), 1)
            XCTAssertEqual(animation.frame(at: -1), 1)
        }
    }
}
