import SwiftUI

// MARK: - Overview
//
// TextFragment renders attributed content as SwiftUI.Text with support for inline
// attachments, links, and selection. It uses a TextBuilder to construct and cache
// Text values, minimizing rebuilds during resize by keying on attachment sizes.
//
// Attachments are represented as placeholder images tagged with AttachmentAttribute. The
// actual attachment views are rendered in an overlay using the resolved Text.Layout
// geometry. Three modifiers are applied at the fragment level:
//
// - TextSelectionBackground renders selection highlights on macOS
// - AttachmentOverlay draws attachments at their run locations with selection-aware dimming
// - TextLinkInteraction handles tap gestures on links
//
// These overlays use backgroundPreferenceValue and overlayPreferenceValue to access
// Text.Layout and render in fragment-local coordinates. Fragment-level overlays enable
// coordinate space isolation and keep scrollable regions interactive.
//
// An ancestor view must define a named coordinate space (.textContainer) for the text
// container. TextFragment uses onGeometryChange to observe the container size and rebuild
// Text when attachment sizes need to change.
//
// TextFragment is used by InlineText and StructuredText (via BlockContent) to render
// attributed content with inline attachments, links, and selection.

struct TextFragment<Content: AttributedStringProtocol>: View {
  @Environment(\.textEnvironment) private var textEnvironment
  @Environment(\.textReveal) private var reveal
  @Environment(\.textRevealOffset) private var revealOffset
  @State private var builder = Derived<Content, TextBuilder>()

  private let content: Content

  init(_ content: Content) {
    self.content = content
  }

  var body: some View {
    let textBuilder = builder(content) { TextBuilder(content, environment: textEnvironment) }
    let text = textBuilder.text
      .customAttribute(TextFragmentAttribute(offset: revealOffset, characters: textBuilder.characters))
    Group {
      if let reveal {
        // Read aloud only as far as it shows.
        text
          .textRenderer(TextRevealRenderer(count: reveal))
          .accessibilityLabel(Text(verbatim: String(content.characters.prefix(max(0, reveal - revealOffset)))))
      } else {
        text
      }
    }
      .onGeometryChange(for: CGSize?.self, of: \.textContainerSize) { size in
        guard let size else { return }
        textBuilder.sizeChanged(size, environment: textEnvironment)
      }
      .modifier(TextSelectionBackground())
      .modifier(AttachmentOverlay(attachments: content.attachments(), reveal: reveal))
      .modifier(TextLinkInteraction(reveal: reveal))
  }
}

struct TextFragmentAttribute: TextAttribute {
  /// Where the fragment's content starts in the revealed content, in characters (`textual.revealCharacters`).
  let offset: Int
  let characters: TextFragmentCharacters
}

extension Text.Layout {
  var isTextFragment: Bool {
    first?.first?[TextFragmentAttribute.self] != nil
  }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
  static var textContainer: NamedCoordinateSpace {
    .named("textContainer")
  }
}

extension GeometryProxy {
  fileprivate var textContainerSize: CGSize? {
    bounds(of: .textContainer)?.size
  }
}
