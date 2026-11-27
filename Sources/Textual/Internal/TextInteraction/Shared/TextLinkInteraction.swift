import SwiftUI

// MARK: - Overview
//
// `TextLinkInteraction` adds lightweight link tapping to a `Text` fragment.
//
// SwiftUI resolves a `Text.Layout` for each fragment and publishes it through the `Text.LayoutKey`
// preference. This modifier reads the anchored layout, converts tap locations to layout-local
// coordinates, and looks for the first run whose typographic bounds contains the tap. When a run
// has a `url`, the modifier invokes the environment’s `openURL` action; otherwise it invokes the
// optional plain text tap action set with `onPlainTextTap(_:)`.

struct TextLinkInteraction: ViewModifier {
  @Environment(\.openURL) private var openURL
  @Environment(\.plainTextTapAction) private var plainTextTapAction
  /// The revealed characters (`textual.revealCharacters`); a link that does not show yet is not hit.
  private let reveal: Int?

  init(reveal: Int?) {
    self.reveal = reveal
  }

  func body(content: Content) -> some View {
    #if TEXTUAL_ENABLE_LINKS
      content
        .overlayPreferenceValue(Text.LayoutKey.self) { value in
          if let anchoredLayout = value.first {
            GeometryReader { geometry in
              Color.clear
                .contentShape(.rect)
                .gesture(
                  tap(
                    origin: geometry[anchoredLayout.origin],
                    layout: anchoredLayout.layout
                  )
                )
            }
          }
        }
    #else
      content
    #endif
  }

  #if TEXTUAL_ENABLE_LINKS
    private func tap(origin: CGPoint, layout: Text.Layout) -> some Gesture {
      SpatialTapGesture()
        .onEnded { value in
          let localPoint = CGPoint(
            x: value.location.x - origin.x,
            y: value.location.y - origin.y
          )
          let runs = layout.flatMap(\.self)
          let end = layout.textualRevealEnd(reveal)
          let run = runs.first { run in
            guard let end else { return run.typographicBounds.rect.contains(localPoint) }
            return run.contains { slice in
              slice.typographicBounds.rect.contains(localPoint) && slice.characterIndices.contains { $0 < end }
            }
          }
          switch TextTapResolution(url: run?.url, hasActiveSelection: false) {
          case .openURL(let url):
            openURL(url)
          case .clearSelection:
            break
          case .plainText:
            plainTextTapAction?()
          }
        }
    }
  #endif
}

/// What a single tap on rendered text should do.
enum TextTapResolution: Equatable {
  /// The tap hit a link.
  case openURL(URL)
  /// The tap missed any link while a non-collapsed selection was active.
  case clearSelection
  /// The tap landed on plain text with no active selection.
  case plainText

  init(url: URL?, hasActiveSelection: Bool) {
    if let url {
      self = .openURL(url)
    } else if hasActiveSelection {
      self = .clearSelection
    } else {
      self = .plainText
    }
  }
}

private struct PlainTextTapActionKey: EnvironmentKey {
  static var defaultValue: (() -> Void)? { nil }
}

extension EnvironmentValues {
  var plainTextTapAction: (() -> Void)? {
    get { self[PlainTextTapActionKey.self] }
    set { self[PlainTextTapActionKey.self] = newValue }
  }
}
