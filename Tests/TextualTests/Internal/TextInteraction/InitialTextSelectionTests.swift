#if TEXTUAL_ENABLE_TEXT_SELECTION && !targetEnvironment(macCatalyst)
  import Foundation
  import SwiftUI
  import Testing

  @testable import Textual

  struct InitialTextSelectionTrackerTests {
    private let request = InitialTextSelection(windowPoint: CGPoint(x: 10, y: 20))

    @Test
    func waitsUntilReady() {
      var tracker = InitialTextSelectionTracker()
      tracker.update(request)

      #expect(tracker.take(isReady: false, contains: { _ in true }) == nil)
      #expect(tracker.pending == request)
      #expect(tracker.take(isReady: true, contains: { _ in true }) == request)
      #expect(tracker.pending == nil)
    }

    @Test
    func consumesEachIDOnce() {
      var tracker = InitialTextSelectionTracker()
      tracker.update(request)
      _ = tracker.take(isReady: true, contains: { _ in true })

      tracker.update(request)

      #expect(tracker.pending == nil)
      #expect(tracker.take(isReady: true, contains: { _ in true }) == nil)
    }

    @Test
    func newIDReplacesPendingRequest() {
      var tracker = InitialTextSelectionTracker()
      let newer = InitialTextSelection(windowPoint: CGPoint(x: 30, y: 40))
      tracker.update(request)
      tracker.update(newer)

      #expect(tracker.take(isReady: true, contains: { _ in true }) == newer)
    }

    @Test
    func nilClearsPendingRequest() {
      var tracker = InitialTextSelectionTracker()
      tracker.update(request)
      tracker.update(nil)

      #expect(tracker.pending == nil)
      #expect(tracker.take(isReady: true, contains: { _ in true }) == nil)
    }

    @Test
    func returningToConsumedIDDoesNotReapplyIt() {
      var tracker = InitialTextSelectionTracker()
      let other = InitialTextSelection(windowPoint: CGPoint(x: 30, y: 40))
      tracker.update(request)
      _ = tracker.take(isReady: true, contains: { _ in true })
      tracker.update(other)
      _ = tracker.take(isReady: true, contains: { _ in true })

      tracker.update(request)

      #expect(tracker.pending == nil)
    }

    @Test
    func consumedIDClearsRequestWaitingForLayout() {
      var tracker = InitialTextSelectionTracker()
      let other = InitialTextSelection(windowPoint: CGPoint(x: 30, y: 40))
      tracker.update(request)
      _ = tracker.take(isReady: true, contains: { _ in true })
      tracker.update(other)
      #expect(tracker.take(isReady: false, contains: { _ in true }) == nil)

      tracker.update(request)

      #expect(tracker.pending == nil)
      #expect(tracker.take(isReady: true, contains: { _ in true }) == nil)
    }

    @Test
    func pointOutsideViewIsSkippedAndConsumed() {
      var tracker = InitialTextSelectionTracker()
      tracker.update(request)

      #expect(tracker.take(isReady: true, contains: { _ in false }) == nil)

      tracker.update(request)
      #expect(tracker.pending == nil)
    }
  }

  struct InitialSelectionRangeTests {
    private let word = TextRange(
      start: .init(
        indexPath: .init(runSlice: 0, run: 0, line: 0, layout: 0), affinity: .downstream),
      end: .init(indexPath: .init(runSlice: 3, run: 0, line: 0, layout: 0), affinity: .upstream)
    )

    // Inside the first paragraph's text.
    private let point = CGPoint(x: 36, y: 25)
    // Past the end of the first paragraph's last line.
    private let lineEndPoint = CGPoint(x: 200, y: 48)

    @Test
    func prefersForwardWord() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      var directions: [Bool] = []

      let range = model.initialSelectionRange(at: point, position: model.startPosition) {
        forward in
        directions.append(forward)
        return word
      }

      #expect(range == word)
      #expect(directions == [true])
    }

    @Test
    func fallsBackToBackwardWord() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let collapsed = TextRange(start: model.startPosition, end: model.startPosition)

      let range = model.initialSelectionRange(at: point, position: model.startPosition) {
        forward in
        forward ? collapsed : word
      }

      #expect(range == word)
    }

    @Test
    func fallsBackToCharacterUnderPoint() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let position = try #require(model.closestPosition(to: point))

      let range = model.initialSelectionRange(at: point, position: position) { _ in nil }

      #expect(range == model.characterRange(at: point))
    }

    @Test
    func characterFallbackAtLineEndStaysInParagraph() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let position = try #require(model.closestPosition(to: lineEndPoint))

      let range = try #require(
        model.initialSelectionRange(at: lineEndPoint, position: position) { _ in nil }
      )

      #expect(range == model.characterRange(at: lineEndPoint))
      #expect(range.start.indexPath.layout == 0)
      #expect(range.end.indexPath.layout == 0)
      #expect(range.start.indexPath.line == 1)
      #expect(range.end.indexPath.line == 1)
    }

    @Test
    func characterEnclosingPositionAfterStart() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let start = model.startPosition

      let range = try #require(model.characterRange(enclosing: start))

      #expect(range.start == start)
      #expect(model.offset(from: range.start, to: range.end) == 1)
    }

    @Test
    func characterEnclosingPositionBeforeEndOfText() throws {
      let model = try TextSelectionModel(fixtureName: "two-paragraphs-bidi")
      let end = model.endPosition

      let range = try #require(model.characterRange(enclosing: end))

      #expect(range.end == end)
      #expect(model.offset(from: range.start, to: range.end) == 1)
    }

    @Test
    func emptyLayoutIsNotReady() throws {
      let model = try TextSelectionModel(fixtureName: "empty")

      #expect(model.hasLayout == false)
      #expect(model.closestPosition(to: CGPoint(x: 10, y: 10)) == nil)
    }

    @Test
    func layoutChangeNotifiesOnceLayoutIsReady() throws {
      let model = TextSelectionModel()
      let collection = try TextSelectionModel.fixtureLayoutCollection(named: "two-paragraphs-bidi")
      var notifications = 0
      model.layoutCollectionDidChange = { notifications += 1 }

      model.setLayoutCollection(collection)
      model.setLayoutCollection(collection)

      #expect(model.hasLayout)
      #expect(notifications == 1)
    }
  }
#endif
