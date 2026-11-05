#if os(macOS)
  import AppKit
  import SwiftUI
  import Testing

  import Textual

  extension StructuredText {
    // A newly hosted text view must report its final content and block spacing on its first pass.
    @MainActor
    struct FirstLayoutTests {
      private final class Heights {
        var values: [CGFloat] = []
      }

      @Test(arguments: [DynamicTypeSize.large, .accessibility3])
      func firstMeasurementIncludesBlockSpacing(dynamicTypeSize: DynamicTypeSize) {
        let host = NSHostingController(
          rootView: StructuredText(markdown: """
            # Heading

            - Outer item
              - Inner item
              - Another inner item
            - Another outer item

            > Quoted paragraph
            >
            > - Quoted item
            >   - Nested quoted item
            >
            > ```swift
            > let value = 42
            > ```

            First paragraph after the quote.

            Second paragraph after the quote.

            Third paragraph after the quote.
            """)
            .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 36 : 18))
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .fixedSize(horizontal: false, vertical: true)
        )
        host.sizingOptions = []
        let proposal = CGSize(width: 644, height: CGFloat.greatestFiniteMagnitude)
        let first = host.sizeThatFits(in: proposal)
        host.view.frame = CGRect(origin: .zero, size: first)
        for _ in 0..<6 {
          host.view.layoutSubtreeIfNeeded()
          RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        let settled = host.sizeThatFits(in: proposal)
        #expect(first == settled)
      }

      @Test func firstReportedHeightIsTheContents() throws {
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
        host.layoutSubtreeIfNeeded()
        let first = try #require(heights.values.first)
        #expect(first > 40, "heights: \(heights.values)")
      }
    }
  }
#endif
