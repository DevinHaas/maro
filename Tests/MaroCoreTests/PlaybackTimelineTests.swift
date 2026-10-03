import Testing
@testable import MaroCore

@Test func timelineUsesFiniteSeekableRangesAndClampsGaps() throws {
    #expect(PlaybackTimeline(duration: .infinity, ranges: [0...30]) == nil)
    #expect(PlaybackTimeline(duration: 0, ranges: [0...30]) == nil)
    #expect(PlaybackTimeline(duration: 30, ranges: []) == nil)
    #expect(PlaybackTimeline(duration: 30, ranges: [40...50, 0...0]) == nil)
    let timeline = try #require(PlaybackTimeline(duration: 100,
        ranges: [60...120, -10...20, 0...Double.infinity]))
    #expect(timeline.ranges == [0...20, 60...100])
    #expect(timeline.target(for: -5) == 0)
    #expect(timeline.target(for: 10) == 10)
    #expect(timeline.target(for: 40) == 20)
    #expect(timeline.target(for: 41) == 60)
    #expect(timeline.target(for: 200) == 100)
    #expect(timeline.target(for: .nan) == nil)
    #expect(timeline.target(for: .infinity) == nil)
}
