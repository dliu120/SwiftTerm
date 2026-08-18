import XCTest

@testable import SwiftTerm

#if os(macOS)
final class InteractionPresentationProfilerTests: XCTestCase {
    func testSplitMarkerTagsOnlyTheCausalFrame() throws {
        let profiler = InteractionPresentationProfiler(enabled: true)
        let token = try XCTUnwrap(profiler.postedSyntheticKey())
        profiler.receivedSyntheticKey(token)
        let unrelatedFrame = profiler.captureFrame()

        profiler.observeOutput(Array("\u{1b}]9999;shepherd-".utf8)[...])
        profiler.observeOutput(Array("profile\u{7}*".utf8)[...])
        let causalFrame = profiler.captureFrame()

        XCTAssertNil(unrelatedFrame.maximumToken)
        XCTAssertEqual(causalFrame.maximumToken, token)
        profiler.presented(unrelatedFrame)
        XCTAssertEqual(profiler.captureFrame().maximumToken, token)
        profiler.presented(causalFrame)
        XCTAssertNil(profiler.captureFrame().maximumToken)
    }

    func testOneCausalFrameCoalescesMarkedInteractionsExactlyOnce() throws {
        let profiler = InteractionPresentationProfiler(enabled: true)
        let marker = Array("\u{1b}]9999;shepherd-profile\u{7}".utf8)
        let first = try XCTUnwrap(profiler.postedSyntheticKey())
        let second = try XCTUnwrap(profiler.postedSyntheticKey())
        profiler.receivedSyntheticKey(first)
        profiler.receivedSyntheticKey(second)
        profiler.observeOutput(marker[...])
        profiler.observeOutput(marker[...])
        let frame = profiler.captureFrame()

        XCTAssertEqual(frame.maximumToken, second)
        profiler.presented(frame)
        profiler.presented(frame)
        XCTAssertNil(profiler.captureFrame().maximumToken)
    }

    func testDisabledProfilerRetainsNoSamples() {
        let profiler = InteractionPresentationProfiler(enabled: false)

        XCTAssertNil(profiler.postedSyntheticKey())
        XCTAssertNil(profiler.captureFrame().maximumToken)
    }
}
#endif
