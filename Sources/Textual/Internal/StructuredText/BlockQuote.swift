import SwiftUI

extension StructuredText {
  struct BlockQuote: View {
    @Environment(\.blockQuoteStyle) private var blockQuoteStyle

    private let intent: PresentationIntent.IntentType?
    private let content: AttributedSubstring

    init(intent: PresentationIntent.IntentType?, content: AttributedSubstring) {
      self.intent = intent
      self.content = content
    }

    var body: some View {
      Group(subviews: BlockContent(parent: intent, content: content)) { blocks in
        ForEach(blocks) { block in
          let configuration = BlockStyleConfiguration(
            label: .init(block),
            indentationLevel: indentationLevel
          )
          let resolvedStyle = blockQuoteStyle.resolve(configuration: configuration)

          AnyView(resolvedStyle)
            .textual.blockSpacing(block.containerValues.textualBlockSpacing)
        }
      }
    }

    private var indentationLevel: Int {
      content.runs.first?.presentationIntent?.indentationLevel ?? 0
    }
  }
}
