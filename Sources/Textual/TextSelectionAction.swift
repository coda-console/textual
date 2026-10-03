import SwiftUI

/// A custom command offered in the menu of selected text, ahead of the built-in Copy and Share.
///
/// The handler receives the selection as plain text, formatted the same way as Copy.
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct TextSelectionAction: Identifiable {
  public let id: String
  public let title: String
  public let systemImage: String?
  public let perform: @MainActor (String) -> Void

  public init(
    _ title: String,
    systemImage: String? = nil,
    perform: @escaping @MainActor (String) -> Void
  ) {
    self.id = title
    self.title = title
    self.systemImage = systemImage
    self.perform = perform
  }
}

extension EnvironmentValues {
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  @Entry var textSelectionActions: [TextSelectionAction] = []
}

extension TextualNamespace where Base: View {
  /// Adds commands to the menu shown for selected text in ``InlineText`` and ``StructuredText``.
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public func textSelectionActions(_ actions: [TextSelectionAction]) -> some View {
    base.environment(\.textSelectionActions, actions)
  }
}
