import CoreGraphics
import SwiftUI
import Testing

@testable import Textual

struct AttachmentDrawingBoundsTests {
  private struct Placed: Textual.Attachment {
    var description: String { "" }
    var body: some View { Color.clear }
    func sizeThatFits(_: ProposedViewSize, in _: TextEnvironmentValues) -> CGSize { .zero }
  }

  private struct LineTall: Textual.Attachment {
    var description: String { "" }
    var body: some View { Color.clear }
    func sizeThatFits(_: ProposedViewSize, in _: TextEnvironmentValues) -> CGSize { .zero }
    func drawingBounds(placeholder: CGRect, line: CGRect) -> CGRect {
      CGRect(x: placeholder.minX, y: line.minY, width: 2, height: line.height)
    }
  }

  @Test
  func drawsInItsPlaceholderUnlessItSaysOtherwise() {
    // given
    let placeholder = CGRect(x: 10, y: 4, width: 0.01, height: 0.01)
    let line = CGRect(x: 0, y: 0, width: 100, height: 17)

    // then
    #expect(AnyAttachment(Placed()).drawingBounds(placeholder: placeholder, line: line) == placeholder)
    #expect(
      AnyAttachment(LineTall()).drawingBounds(placeholder: placeholder, line: line)
        == CGRect(x: 10, y: 0, width: 2, height: 17)
    )
  }
}
