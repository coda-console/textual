#if os(macOS)
  import AppKit
  import SwiftUI
  import Testing
  @testable import Textual

  @MainActor
  struct BlockStyleSpacingTests {
    private final class Frames {
      var values: [Int: CGRect] = [:]
    }

    private func fixture(_ name: String) throws -> String {
      let url = try #require(Bundle.module.url(
        forResource: name, withExtension: "md", subdirectory: "Fixtures/BlockSpacing"
      ))
      return try String(contentsOf: url, encoding: .utf8)
    }

    private func measure(_ content: some View) -> (first: CGSize, settled: CGSize) {
      let host = NSHostingController(rootView: content
        .font(.system(size: 18))
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true))
      host.sizingOptions = []
      let proposal = CGSize(width: 644, height: CGFloat.greatestFiniteMagnitude)
      let first = host.sizeThatFits(in: proposal)
      host.view.frame = CGRect(origin: .zero, size: first)
      for _ in 0..<8 {
        host.view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
      }
      return (first, host.sizeThatFits(in: proposal))
    }

    @Test(arguments: [false, true])
    func allBlockMarginsMatchLegacy(gitHub: Bool) throws {
      let text = try AttributedString(markdown: fixture("all-blocks"))
      let runs = text.blockRuns(parent: nil)
      let frames = Frames()
      let blocks = StructuredText.BlockVStack {
        ForEach(runs.indices, id: \.self) { index in
          let run = runs[index]
          Group(subviews: StructuredText.Block(intent: run.intent, content: text[run.range])) {
            children in
            ForEach(children) { child in
              child
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .named("blocks")) }) {
                  frames.values[index] = $0
                }
                // The geometry observer is a container; forward the block's root metadata.
                .containerValue(\.textualBlockSpacing, child.containerValues.textualBlockSpacing)
            }
          }
        }
      }
      .coordinateSpace(name: "blocks")
      if gitHub {
        _ = measure(blocks.textual.structuredTextStyle(.gitHub))
      } else {
        _ = measure(blocks.textual.structuredTextStyle(.default))
      }
      let bounds = try runs.indices.map { try #require(frames.values[$0]) }
      let gaps = zip(bounds, bounds.dropFirst()).map { $1.minY - $0.maxY }
      // Measured after settling the preference-based implementation at a5740cb,
      // with an 18 pt font and a 644 pt proposal. Each pair is before/after its block.
      let expected: [CGFloat] = gitHub ? [
        24, 16, 24, 16, 24, 16, 24, 16, 24, 16, 24, 16,  // H1–H6
        16, 16, 16, 16,  // unordered and ordered lists
        16, 16, 16, 16,  // quote and code
        16, 16, 24, 24,  // table and thematic break
      ] : [
        28.8, 14.4, 28.8, 14.4, 28.8, 14.4, 28.8, 14.4, 28.8, 14.4, 28.8, 14.4,
        14.4, 14.4, 14.4, 14.4,
        15.84, 14.4, 15.84, 14.4,
        28.8, 28.8, 28.8, 28.8,
      ]
      #expect(gaps.count == expected.count)
      for (index, pair) in zip(gaps, expected).enumerated() {
        #expect(abs(pair.0 - pair.1) < 0.001, "Gap after block \(index), GitHub: \(gitHub)")
      }
    }

    private struct CodaParagraphStyle: StructuredText.ParagraphStyle {
      func makeBody(configuration: Configuration) -> some View {
        configuration.label
          .textual.lineSpacing(.fontScaled(0.4))
          .textual.blockSpacing(.init(top: 0, bottom: 16))
      }
    }

    @Test func codaMessageFirstHeightMatchesLegacy() throws {
      let sizes = measure(
        StructuredText(markdown: try fixture("coda-message"))
          .textual.paragraphStyle(CodaParagraphStyle())
          .textual.structuredTextStyle(.gitHub)
      )
      #expect(sizes.first == sizes.settled)
      // The same fixture and Coda paragraph style settle at 524 pt on a5740cb.
      #expect(abs(sizes.settled.height - 524) < 0.001)
    }
  }
#endif
