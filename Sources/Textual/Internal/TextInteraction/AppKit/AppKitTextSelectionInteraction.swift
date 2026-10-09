#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(AppKit) && !targetEnvironment(macCatalyst)
  import SwiftUI

  // MARK: - Overview
  //
  // `AppKitTextSelectionInteraction` presents the platform-specific text selection overlay for macOS.
  //
  // The modifier receives a `TextSelectionModel` and places it in the environment so selection highlights
  // and attachment dimming can access it. An overlay hosts `AppKitTextInteractionOverlay`, which wraps an
  // `NSView` that handles selection gestures, context menus and native cursor updates.

  typealias PlatformTextSelectionInteraction = AppKitTextSelectionInteraction

  struct AppKitTextSelectionInteraction: ViewModifier {
    private let model: TextSelectionModel

    init(model: TextSelectionModel) {
      self.model = model
    }

    func body(content: Content) -> some View {
      content
        // We need the selection model at text fragment level for the
        // text selection background and selected attachment dimming
        .environment(model)
        .overlayPreferenceValue(OverflowFrameKey.self) { frames in
          AppKitTextInteractionOverlay(model: model, overflowFrames: frames)
        }
    }
  }
#endif
