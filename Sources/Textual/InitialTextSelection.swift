import SwiftUI

/// A request to start text selection at a point, as if the user had long-pressed there.
///
/// Pass a new value with a fresh `id` to ``TextualNamespace/initialTextSelection(_:)`` when
/// switching text into selection mode. The text view that contains `windowPoint` selects the
/// enclosing word and shows the selection handles. Each `id` is applied at most once, so later
/// view updates don't override a selection the user has since adjusted.
///
/// This request takes effect on iOS-family platforms only.
public struct InitialTextSelection: Equatable, Sendable {
  /// Identifies this request. Use a new identifier for every request.
  public var id: UUID
  /// The point to select at, in window coordinates.
  public var windowPoint: CGPoint

  public init(id: UUID = UUID(), windowPoint: CGPoint) {
    self.id = id
    self.windowPoint = windowPoint
  }
}

extension EnvironmentValues {
  @Entry var initialTextSelection: InitialTextSelection? = nil
}

extension TextualNamespace where Base: View {
  /// Selects the word at the request's point as soon as the text layout is ready.
  ///
  /// Use together with ``TextualNamespace/textSelection(_:)``. Has no effect on platforms
  /// without UIKit text selection.
  public func initialTextSelection(_ request: InitialTextSelection?) -> some View {
    base.environment(\.initialTextSelection, request)
  }
}
