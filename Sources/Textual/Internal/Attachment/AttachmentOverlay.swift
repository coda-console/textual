import SwiftUI

// MARK: - Overview
//
// `AttachmentOverlay` renders attachment views using resolved `Text.Layout` geometry.
//
// It’s applied at the text fragment level. The fragment exposes the resolved layout through the
// `Text.LayoutKey` preference; this modifier reads the anchored layout, converts its anchor to a
// concrete origin using `GeometryReader`, and installs an `AttachmentView` that draws attachments
// at their run bounds.

struct AttachmentOverlay: ViewModifier {
  private let attachments: Set<AnyAttachment>
  private let reveal: Int?

  init(attachments: Set<AnyAttachment>, reveal: Int?) {
    self.attachments = attachments
    self.reveal = reveal
  }

  func body(content: Content) -> some View {
    content
      .overlayPreferenceValue(Text.LayoutKey.self) { value in
        if let anchoredLayout = value.first {
          GeometryReader { geometry in
            AttachmentView(
              attachments: attachments,
              origin: geometry[anchoredLayout.origin],
              layout: anchoredLayout.layout,
              revealEnd: anchoredLayout.layout.textualRevealEnd(reveal)
            )
          }
        }
      }
  }
}
