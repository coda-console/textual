import SwiftUI

// MARK: - Overview
//
// Revealing draws a text as far as a number of characters of its content while laying it out whole, so what is
// drawn keeps its line breaks as more of it shows. Each fragment knows where its content starts in the revealed
// content (`textRevealOffset`, set by each block) and how its characters map to its `Text`'s (attachments are one
// placeholder each). It draws the glyphs before its share of the count; selection, links, attachments and
// accessibility reach no further.

extension TextualNamespace where Base: View {
  /// Draws ``StructuredText`` or ``InlineText`` only as far as `count` characters of its content, laying it out whole.
  ///
  /// A glyph shows once the first character it draws is reached, an attachment once its first character is. Selection,
  /// links, attachments and accessibility reach only what shows. `nil` shows all of it.
  public func revealCharacters(_ count: Int?) -> some View {
    base.environment(\.textReveal, count)
  }
}

extension Text.Layout {
  /// Where the drawn glyphs of a fragment end when its ``StructuredText`` or ``InlineText`` reveals `count` characters
  /// (`textual.revealCharacters`): a run slice shows when one of its characters comes before it. `nil` where all show.
  public func textualRevealEnd(_ count: Int?) -> Text.Layout.CharacterIndex? {
    guard let length = revealedLength(count),
      let first = lazy.flatMap({ $0.flatMap(\.characterIndices) }).min()
    else { return nil }
    return first.advanced(by: length)
  }

  /// The UTF-16 code units of the fragment's text that show when `count` characters are revealed; nil where all do.
  func revealedLength(_ count: Int?) -> Int? {
    guard let count, let fragment = first?.first?[TextFragmentAttribute.self] else { return nil }
    return fragment.characters.revealedLength(Swift.max(0, count - fragment.offset))
  }
}

/// A fragment's content, for revealing it as far as some of its characters.
final class TextFragmentCharacters: Hashable, Sendable {
  private let content: AttributedString
  private let length: Int

  init(_ content: some AttributedStringProtocol) {
    let content = AttributedString(content[content.startIndex..<content.endIndex])
    self.content = content
    self.length = Self.units(Int.max, in: content)
  }

  /// The UTF-16 code units of the fragment's `Text` that `count` of its characters make; nil where that is all of them.
  func revealedLength(_ count: Int) -> Int? {
    let units = Self.units(count, in: content)
    return units < length ? units : nil
  }

  private static func units(_ count: Int, in content: AttributedString) -> Int {
    var left = count, units = 0
    for run in content.runs {
      guard left > 0 else { break }
      let characters = content[run.range].characters
      // TextBuilder draws an attachment as a single placeholder.
      units += run.textual.attachment != nil ? 1 : String(characters.prefix(left)).utf16.count
      left -= characters.count
    }
    return units
  }

  static func == (lhs: TextFragmentCharacters, rhs: TextFragmentCharacters) -> Bool { lhs === rhs }
  func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

/// Draws a fragment's glyphs as far as the revealed characters reach.
struct TextRevealRenderer: TextRenderer {
  let count: Int

  func draw(layout: Text.Layout, in context: inout GraphicsContext) {
    guard let end = layout.textualRevealEnd(count) else {
      for line in layout { context.draw(line) }
      return
    }
    for line in layout {
      let indices = line.flatMap(\.characterIndices)
      if let last = indices.max(), last < end {
        context.draw(line)
        continue
      }
      for run in line {
        for slice in run where slice.characterIndices.contains(where: { $0 < end }) { context.draw(slice) }
      }
    }
  }
}

extension EnvironmentValues {
  /// The characters of a StructuredText's or InlineText's content that show; nil for all of them.
  @Entry var textReveal: Int? = nil
  /// Where the current block's content starts in the revealed content, in characters.
  @Entry var textRevealOffset = 0
}
