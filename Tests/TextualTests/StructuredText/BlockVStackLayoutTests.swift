#if os(macOS)
  import AppKit
  import SwiftUI
  import Testing
  @testable import Textual

  @MainActor
  struct BlockVStackLayoutTests {
    private final class Measurements {
      var count = 0
    }

    // Omitting spacing exercises the protocol's default, uncached implementation.
    private struct UncachedLayout: Layout {
      func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let layout = StructuredText.BlockVStackLayout(textAlignment: .leading)
        var freshCache = layout.makeCache(subviews: subviews)
        return layout.sizeThatFits(proposal: proposal, subviews: subviews, cache: &freshCache)
      }

      func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
      ) {}
    }

    private struct CheckLayout: Layout {
      let measurements: Measurements

      func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let layout = StructuredText.BlockVStackLayout(textAlignment: .leading)
        let baseline = UncachedLayout()
        var cached = layout.makeCache(subviews: subviews)
        let expected = baseline.spacing(subviews: subviews, cache: &cache)
        for _ in 0..<2 {
          let actual = layout.spacing(subviews: subviews, cache: &cached)
          // Compare observable spacing in both directions on both axes (all four edges).
          for subview in subviews {
            for axis in [Axis.horizontal, .vertical] {
              #expect(
                actual.distance(to: subview.spacing, along: axis)
                  == expected.distance(to: subview.spacing, along: axis))
              #expect(
                subview.spacing.distance(to: actual, along: axis)
                  == subview.spacing.distance(to: expected, along: axis))
            }
          }
        }
        #expect(cached.preferredSpacing != nil)
        let size = layout.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cached)
        #expect(
          size == baseline.sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache))
        layout.updateCache(&cached, subviews: subviews)
        #expect(cached.preferredSpacing == nil)
        measurements.count += 1
        return size
      }

      func placeSubviews(
        in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
      ) {
        let layout = StructuredText.BlockVStackLayout(textAlignment: .leading)
        var freshCache = layout.makeCache(subviews: subviews)
        layout.placeSubviews(in: bounds, proposal: proposal, subviews: subviews, cache: &freshCache)
      }
    }

    @Test func nestedMarkdownSpacingAndSizeMatchDefault() {
      let measurements = Measurements()
      let markdown = """
        - Outer list
          - Inner list
            - Deeply nested item

        > Quote
        >
        > ```swift
        > let value = 42
        > ```
        """
      func content(_ text: String, large: Bool) -> some View {
        CheckLayout(measurements: measurements) {
          StructuredText(markdown: text)
          Text("Adjacent block")
        }
        .textual.structuredTextStyle(.gitHub)
        .font(.system(size: large ? 24 : 14))
        .environment(\.dynamicTypeSize, large ? .accessibility3 : .large)
        .frame(width: 240)
        .fixedSize(horizontal: false, vertical: true)
      }
      let host = NSHostingView(rootView: content(markdown, large: false))
      let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: 240, height: 800),
        styleMask: [.borderless], backing: .buffered, defer: false
      )
      window.isReleasedWhenClosed = false
      window.contentView = host
      defer { window.contentView = nil }
      host.layoutSubtreeIfNeeded()
      #expect(measurements.count > 0)
      measurements.count = 0
      host.rootView = content(markdown + "\n\nAnother paragraph.", large: true)
      host.layoutSubtreeIfNeeded()
      #expect(measurements.count > 0)
    }
  }
#endif
