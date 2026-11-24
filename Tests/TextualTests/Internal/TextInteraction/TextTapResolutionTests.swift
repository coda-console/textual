import Foundation
import SwiftUI
import Testing

@testable import Textual

struct TextTapResolutionTests {
  private let url = URL(string: "https://example.com")!

  @Test
  func linkOpensURLEvenWithActiveSelection() {
    #expect(TextTapResolution(url: url, hasActiveSelection: false) == .openURL(url))
    #expect(TextTapResolution(url: url, hasActiveSelection: true) == .openURL(url))
  }

  @Test
  func plainTextWithActiveSelectionOnlyClearsSelection() {
    #expect(TextTapResolution(url: nil, hasActiveSelection: true) == .clearSelection)
  }

  @Test
  func plainTextWithoutSelectionIsPlainTextTap() {
    #expect(TextTapResolution(url: nil, hasActiveSelection: false) == .plainText)
  }
}

#if os(macOS)
  import AppKit

  @MainActor
  struct PlainTextTapEnvironmentTests {
    private final class Box {
      var action: (() -> Void)?
      var didRead = false
      var calls = 0
    }

    private struct Probe: View {
      @Environment(\.plainTextTapAction) private var action
      let box: Box

      var body: some View {
        box.action = action
        box.didRead = true
        return Color.clear.frame(width: 10, height: 10)
      }
    }

    private func read(_ view: some View, into box: Box) {
      let host = NSHostingView(rootView: view)
      host.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
      host.layoutSubtreeIfNeeded()
    }

    @Test
    func defaultsToNil() {
      let box = Box()
      read(Probe(box: box), into: box)
      #expect(box.didRead)
      #expect(box.action == nil)
    }

    @Test
    func modifierPassesActionThroughEnvironment() {
      let box = Box()
      read(Probe(box: box).textual.onPlainTextTap { box.calls += 1 }, into: box)
      box.action?()
      #expect(box.calls == 1)
    }
  }
#endif
