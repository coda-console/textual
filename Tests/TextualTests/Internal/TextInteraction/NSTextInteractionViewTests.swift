#if TEXTUAL_ENABLE_TEXT_SELECTION && os(macOS)
  import AppKit
  import SwiftUI
  import Testing

  @testable import Textual

  @MainActor
  struct NSTextInteractionViewTests {
    private final class Calls {
      var plainTextTaps = 0
      var openedURLs: [URL] = []
    }

    // Points in the "two-paragraphs-bidi" fixture.
    private let linkPoint = CGPoint(x: 276, y: 25)
    private let plainTextPoint = CGPoint(x: 36, y: 25)

    private let window = NSWindow(
      contentRect: CGRect(x: 0, y: 0, width: 320, height: 200),
      styleMask: [],
      backing: .buffered,
      defer: true
    )

    private func makeView(calls: Calls) throws -> NSTextInteractionView {
      let view = NSTextInteractionView(
        model: try TextSelectionModel(fixtureName: "two-paragraphs-bidi"),
        exclusionRects: [],
        openURL: OpenURLAction { url in
          calls.openedURLs.append(url)
          return .handled
        },
        plainTextTapAction: { calls.plainTextTaps += 1 }
      )
      view.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
      window.contentView = view
      return view
    }

    private func send(
      _ type: NSEvent.EventType,
      at point: CGPoint,
      to view: NSTextInteractionView
    ) throws {
      let event = try #require(
        NSEvent.mouseEvent(
          with: type,
          location: view.convert(point, to: nil),
          modifierFlags: [],
          timestamp: 0,
          windowNumber: window.windowNumber,
          context: nil,
          eventNumber: 0,
          clickCount: 1,
          pressure: 1
        )
      )
      switch type {
      case .leftMouseDown: view.mouseDown(with: event)
      case .leftMouseDragged: view.mouseDragged(with: event)
      default: view.mouseUp(with: event)
      }
    }

    private func click(at point: CGPoint, on view: NSTextInteractionView) throws {
      try send(.leftMouseDown, at: point, to: view)
      try send(.leftMouseUp, at: point, to: view)
    }

    @Test
    func plainTextClickCallsAction() throws {
      let calls = Calls()
      let view = try makeView(calls: calls)

      try click(at: plainTextPoint, on: view)

      #expect(calls.plainTextTaps == 1)
      #expect(calls.openedURLs.isEmpty)
    }

    @Test
    func linkClickOnlyOpensURL() throws {
      let calls = Calls()
      let view = try makeView(calls: calls)

      try click(at: linkPoint, on: view)

      #expect(calls.openedURLs == [URL(string: "https://example.com")])
      #expect(calls.plainTextTaps == 0)
    }

    @Test
    func linkClickOpensOnMouseUp() throws {
      let calls = Calls()
      let view = try makeView(calls: calls)

      try send(.leftMouseDown, at: linkPoint, to: view)
      #expect(calls.openedURLs.isEmpty)

      try send(.leftMouseUp, at: linkPoint, to: view)
      #expect(calls.openedURLs == [URL(string: "https://example.com")])
    }

    @Test
    func dragFromLinkDoesNotOpenURL() throws {
      let calls = Calls()
      let view = try makeView(calls: calls)

      try send(.leftMouseDown, at: linkPoint, to: view)
      try send(.leftMouseDragged, at: plainTextPoint, to: view)
      try send(.leftMouseUp, at: plainTextPoint, to: view)

      #expect(view.model.selectedRange?.isCollapsed == false)
      #expect(calls.openedURLs.isEmpty)
      #expect(calls.plainTextTaps == 0)
    }

    @Test
    func clickWithActiveSelectionOnlyClearsIt() throws {
      let calls = Calls()
      let view = try makeView(calls: calls)
      view.model.selectedRange = TextRange(
        start: view.model.startPosition,
        end: view.model.endPosition
      )

      try click(at: plainTextPoint, on: view)

      #expect(view.model.selectedRange == nil)
      #expect(calls.plainTextTaps == 0)
    }

    @Test
    func dragSelectionIsNotATap() throws {
      let calls = Calls()
      let view = try makeView(calls: calls)

      try send(.leftMouseDown, at: plainTextPoint, to: view)
      try send(.leftMouseDragged, at: linkPoint, to: view)
      try send(.leftMouseUp, at: linkPoint, to: view)

      #expect(view.model.selectedRange?.isCollapsed == false)
      #expect(calls.plainTextTaps == 0)
    }

    @Test
    func dragBackToStartIsNotATap() throws {
      let calls = Calls()
      let view = try makeView(calls: calls)

      try send(.leftMouseDown, at: plainTextPoint, to: view)
      try send(.leftMouseDragged, at: linkPoint, to: view)
      try send(.leftMouseDragged, at: plainTextPoint, to: view)
      try send(.leftMouseUp, at: plainTextPoint, to: view)

      #expect(view.model.selectedRange?.isCollapsed ?? true)
      #expect(calls.plainTextTaps == 0)
    }
  }
#endif
