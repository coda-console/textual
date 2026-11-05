import SwiftUI

extension ContainerValues {
  var textualBlockSpacing: StructuredText.BlockSpacing {
    get { self[StructuredText.BlockSpacingKey.self] }
    set { self[StructuredText.BlockSpacingKey.self] = textualBlockSpacing.union(newValue) }
  }
}

extension StructuredText {
  // Carry raw margins through block containers before applying the list-item override
  // as a layout value. Multiple margins on the same block retain preference union semantics.
  struct BlockSpacingKey: ContainerValueKey, LayoutValueKey {
    static let defaultValue = BlockSpacing()
  }
}
