#if os(macOS)
  import AppKit
  import SwiftUI
  import Testing

  import Textual

  extension StructuredText {
    // A text view made anew lays out its content in its first pass: the first height it reports is that of its
    // text, not that of an empty view followed by another update. (Block spacing still arrives a pass later, through
    // the blocks' preferences.)
    @MainActor
    struct FirstLayoutTests {
      private final class Heights {
        var values: [CGFloat] = []
      }

      @Test func firstReportedHeightIsTheContents() async throws {
        let heights = Heights()
        let host = NSHostingView(
          rootView: StructuredText(
            markdown: """
              The sky above the port was the color of television, tuned to a dead channel.

              It was a bright **cold** day in April, and the clocks were striking `thirteen`.
              """
          )
          .frame(width: 240)
          .fixedSize(horizontal: false, vertical: true)
          .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { heights.values.append($0) }
        )
        let window = NSWindow(
          contentRect: CGRect(x: 0, y: 0, width: 240, height: 600),
          styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.contentView = nil }
        for _ in 0..<10 {
          host.layoutSubtreeIfNeeded()
          try await Task.sleep(for: .milliseconds(20))
        }
        let first = try #require(heights.values.first)
        #expect(first > 40, "heights: \(heights.values)")
      }
    }
  }
#endif
