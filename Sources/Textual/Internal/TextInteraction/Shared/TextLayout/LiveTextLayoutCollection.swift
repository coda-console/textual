#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  final class LiveTextLayoutCollection: TextLayoutCollection {
    private(set) lazy var layouts: [any TextLayout] = makeLayouts()

    private let base: Text.LayoutKey.Value
    private let geometry: GeometryProxy
    private let reveal: Int?

    init(base: Text.LayoutKey.Value, geometry: GeometryProxy, reveal: Int? = nil) {
      self.base = base
      self.geometry = geometry
      self.reveal = reveal
    }

    func isEqual(to other: any TextLayoutCollection) -> Bool {
      guard let other = other as? LiveTextLayoutCollection else { return false }
      return base == other.base && reveal == other.reveal
    }

    func needsPositionReconciliation(with other: any TextLayoutCollection) -> Bool {
      // Same layouts with different origins do not need position reconciliation
      base.map(\.layout) != (other as? LiveTextLayoutCollection)?.base.map(\.layout)
    }

    func index(of layout: Text.Layout) -> Int? {
      layouts.firstIndex { textLayout in
        (textLayout as? LiveTextLayout)?.base == layout
      }
    }

    private func makeLayouts() -> [any TextLayout] {
      base
        // We are only interested in text fragments
        .filter(\.layout.isTextFragment)
        .map { anchoredLayout in
          LiveTextLayout(
            anchoredLayout: anchoredLayout,
            geometry: geometry,
            revealed: anchoredLayout.layout.revealedLength(reveal)
          )
        }
        // A fragment none of which shows yet has nothing to select.
        .filter { !$0.lines.isEmpty }
    }
  }

  final class LiveTextLayout: TextLayout {
    var attributedString: NSAttributedString {
      guard let revealed else { return joinedAttributedString.joined }
      let joined = joinedAttributedString.joined
      return joined.attributedSubstring(from: NSRange(location: 0, length: min(revealed, joined.length)))
    }

    let origin: CGPoint

    private(set) lazy var bounds: CGRect = makeBounds()
    private(set) lazy var lines: [any TextLine] = makeLines()

    let base: Text.Layout
    /// The UTF-16 code units that show (`textual.revealCharacters`); nil where all do. Lines, runs and slices
    /// after them are left out, so positions, selection and copying stop there.
    private let revealed: Int?

    private lazy var contents = base.materializeContents()
    private lazy var joinedAttributedString = contents.attributedStrings.joined()

    convenience init(
      anchoredLayout: Text.LayoutKey.AnchoredLayout,
      geometry: GeometryProxy,
      revealed: Int? = nil
    ) {
      self.init(
        base: anchoredLayout.layout,
        origin: geometry[anchoredLayout.origin],
        revealed: revealed
      )
    }

    init(base: Text.Layout, origin: CGPoint, revealed: Int? = nil) {
      self.base = base
      self.origin = origin
      self.revealed = revealed
    }

    private func makeBounds() -> CGRect {
      base.map(\.typographicBounds.rect)
        .reduce(CGRect.null, CGRectUnion)
    }

    private func makeLines() -> [any TextLine] {
      guard let revealed else { return makeAllLines() }
      return makeAllLines().prefix { line in
        line.runs.first?.slices.first.map { $0.characterRange.lowerBound < revealed } ?? false
      }.map { RevealedTextLine(base: $0, revealed: revealed) }
    }

    private func makeAllLines() -> [any TextLine] {
      guard contents.attributedStrings.count > 1 else {
        return base.map {
          LiveTextLine(base: $0)
        }
      }

      // Get the offset mappings on the layout strings to maintain object identity
      let (_, characterOffsets) = contents.layoutAttributedStrings.joined()

      return zip(base, contents.lineFragments).compactMap { line, lineFragment in
        guard let offset = characterOffsets[.init(lineFragment.attributedString)] else {
          return nil
        }

        return LiveTextLine(base: line, offset: offset)
      }
    }
  }

  final class LiveTextLine: TextLine {
    var origin: CGPoint {
      base.origin
    }

    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    private(set) lazy var runs: [any TextRun] = makeRuns()

    let base: Text.Layout.Line
    let offset: Int

    init(base: Text.Layout.Line, offset: Int = 0) {
      self.base = base
      self.offset = offset
    }

    private func makeRuns() -> [any TextRun] {
      if base.isEmpty {
        // Return a newline run for empty lines
        return [
          EmptyRun(
            typographicBounds: base.typographicBounds.rect,
            slice: .init(
              typographicBounds: base.typographicBounds.rect,
              characterRange: offset..<(offset + 1)
            )
          )
        ]
      } else {
        return base.map { run in
          LiveTextRun(base: run, offset: offset)
        }
      }
    }
  }

  final class LiveTextRun: TextRun {
    var layoutDirection: LayoutDirection {
      base.layoutDirection
    }

    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    var url: URL? {
      base.url
    }

    private(set) lazy var slices: [any TextRunSlice] = makeRunSlices()

    let base: Text.Layout.Run
    let offset: Int

    init(base: Text.Layout.Run, offset: Int) {
      self.base = base
      self.offset = offset
    }

    private func makeRunSlices() -> [any TextRunSlice] {
      zip(base, base.characterRanges).map { slice, characterRange in
        LiveTextRunSlice(
          base: slice,
          characterRange: characterRange.offset(by: offset)
        )
      }
    }
  }

  /// A line as far as its revealed slices: the runs and slices from the first one that does not show are left out.
  struct RevealedTextLine: TextLine {
    let base: any TextLine
    let runs: [any TextRun]

    init(base: any TextLine, revealed: Int) {
      self.base = base
      self.runs = base.runs.prefix { run in
        run.slices.first.map { $0.characterRange.lowerBound < revealed } ?? false
      }.map { RevealedTextRun(base: $0, revealed: revealed) }
    }

    var origin: CGPoint { base.origin }
    var typographicBounds: CGRect { base.typographicBounds }
  }

  struct RevealedTextRun: TextRun {
    let base: any TextRun
    let slices: [any TextRunSlice]

    init(base: any TextRun, revealed: Int) {
      self.base = base
      self.slices = Array(base.slices.prefix { $0.characterRange.lowerBound < revealed })
    }

    var layoutDirection: LayoutDirection { base.layoutDirection }
    var typographicBounds: CGRect { base.typographicBounds }
    var url: URL? { base.url }
  }

  struct EmptyRun: TextRun {
    let layoutDirection: LayoutDirection = .localeBased()
    let typographicBounds: CGRect
    let url: URL? = nil
    let slice: EmptyRunSlice

    var slices: [any TextRunSlice] {
      [slice]
    }
  }

  final class LiveTextRunSlice: TextRunSlice {
    var typographicBounds: CGRect {
      base.typographicBounds.rect
    }

    let characterRange: Range<Int>
    let base: Text.Layout.RunSlice

    init(base: Text.Layout.RunSlice, characterRange: Range<Int>) {
      self.base = base
      self.characterRange = characterRange
    }
  }

  struct EmptyRunSlice: TextRunSlice {
    let typographicBounds: CGRect
    let characterRange: Range<Int>
  }
#endif
