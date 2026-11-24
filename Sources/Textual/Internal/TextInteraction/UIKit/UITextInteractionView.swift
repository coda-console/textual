#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  import SwiftUI
  import os
  import UniformTypeIdentifiers

  // MARK: - Overview
  //
  // `UITextInteractionView` implements selection and link interaction on iOS-family platforms.
  //
  // The view sits in an overlay above one or more rendered `Text` fragments. It uses
  // `TextSelectionModel` to translate touch locations into URLs and selection ranges, and it
  // respects `exclusionRects` so embedded scrollable regions can continue to handle gestures.
  // Selection UI is provided by `UITextInteraction` configured for non-editable content.

  final class UITextInteractionView: UIView {
    override var canBecomeFirstResponder: Bool {
      true
    }

    var model: TextSelectionModel
    var exclusionRects: [CGRect]
    var openURL: OpenURLAction
    var actions: [TextSelectionAction]
    var plainTextTapAction: (() -> Void)?

    weak var inputDelegate: (any UITextInputDelegate)?

    let logger = Logger(category: .textInteraction)

    private(set) lazy var _tokenizer = UITextInputStringTokenizer(textInput: self)
    private let selectionInteraction: UITextInteraction
    private var initialTextSelection = InitialTextSelectionTracker()
    private var editMenuInteraction: UIEditMenuInteraction?

    init(
      model: TextSelectionModel,
      exclusionRects: [CGRect],
      openURL: OpenURLAction,
      actions: [TextSelectionAction] = [],
      plainTextTapAction: (() -> Void)? = nil
    ) {
      self.model = model
      self.exclusionRects = exclusionRects
      self.openURL = openURL
      self.actions = actions
      self.plainTextTapAction = plainTextTapAction
      self.selectionInteraction = UITextInteraction(for: .nonEditable)

      super.init(frame: .zero)
      self.backgroundColor = .clear

      setUp()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
      for exclusionRect in exclusionRects {
        if exclusionRect.contains(point) {
          return false
        }
      }
      return super.point(inside: point, with: event)
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      applyInitialTextSelection()
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      applyInitialTextSelection()
    }

    func setInitialTextSelection(_ request: InitialTextSelection?) {
      initialTextSelection.update(request)
      if initialTextSelection.pending != nil {
        // Apply on the next layout pass instead of inside the SwiftUI update.
        setNeedsLayout()
      }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
      switch action {
      case #selector(copy(_:)), #selector(share(_:)):
        return !(model.selectedRange?.isCollapsed ?? true)
      default:
        return false
      }
    }

    override func copy(_ sender: Any?) {
      guard let selectedRange = model.selectedRange else {
        return
      }

      let attributedText = model.attributedText(in: selectedRange)
      let formatter = Formatter(selection: attributedText)

      UIPasteboard.general.setItems(
        [
          [
            UTType.plainText.identifier: formatter.plainText(),
            UTType.html.identifier: formatter.html(),
          ]
        ]
      )
    }

    func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
      guard !actions.isEmpty, let selectedRange = model.selectedRange, !selectedRange.isCollapsed else {
        return nil
      }
      let custom = actions.map { action in
        UIAction(title: action.title, image: action.systemImage.flatMap { UIImage(systemName: $0) }) {
          [weak self] _ in
          self?.perform(action)
        }
      }
      return UIMenu(children: custom + suggestedActions)
    }

    private func perform(_ action: TextSelectionAction) {
      guard let selectedRange = model.selectedRange, !selectedRange.isCollapsed else {
        return
      }
      let text = Formatter(selection: model.attributedText(in: selectedRange)).plainText()
      model.selectedRange = nil
      action.perform(text)
    }

    private func setUp() {
      model.selectionWillChange = { [weak self] in
        guard let self else { return }
        self.inputDelegate?.selectionWillChange(self)
      }
      model.selectionDidChange = { [weak self] in
        guard let self else { return }
        self.inputDelegate?.selectionDidChange(self)
      }
      model.layoutCollectionDidChange = { [weak self] in
        guard let self, self.initialTextSelection.pending != nil else { return }
        self.setNeedsLayout()
      }

      let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
      addGestureRecognizer(tapGesture)

      selectionInteraction.textInput = self
      selectionInteraction.delegate = self

      for gesture in selectionInteraction.gesturesForFailureRequirements {
        tapGesture.require(toFail: gesture)
      }

      addInteraction(selectionInteraction)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
      let location = gesture.location(in: self)
      let resolution = TextTapResolution(
        url: model.url(for: location),
        hasActiveSelection: !(model.selectedRange?.isCollapsed ?? true)
      )
      switch resolution {
      case .openURL(let url):
        openURL(url)
      case .clearSelection:
        model.selectedRange = nil
      case .plainText:
        model.selectedRange = nil
        plainTextTapAction?()
      }
    }

    private func applyInitialTextSelection() {
      guard
        let request = initialTextSelection.take(
          isReady: window != nil && !bounds.isEmpty && model.hasLayout,
          contains: { request in
            let localPoint = convert(request.windowPoint, from: nil)
            return bounds.contains(localPoint) && point(inside: localPoint, with: nil)
          }
        )
      else {
        return
      }

      let localPoint = convert(request.windowPoint, from: nil)
      guard
        let position = model.closestPosition(to: localPoint),
        let range = model.initialSelectionRange(
          at: localPoint,
          position: position,
          wordRange: { forward in
            let range = rangeEnclosingPosition(
              TextPositionBox(position),
              with: .word,
              inDirection: .storage(forward ? .forward : .backward)
            )
            return (range as? TextRangeBox)?.wrappedValue
          }
        )
      else {
        return
      }

      _ = becomeFirstResponder()
      selectedTextRange = TextRangeBox(range)
      presentEditMenu(at: localPoint)
    }

    private func presentEditMenu(at point: CGPoint) {
      let interaction: UIEditMenuInteraction
      if let editMenuInteraction {
        interaction = editMenuInteraction
      } else {
        interaction = UIEditMenuInteraction(delegate: self)
        addInteraction(interaction)
        editMenuInteraction = interaction
      }
      interaction.presentEditMenu(
        with: UIEditMenuConfiguration(identifier: nil, sourcePoint: point)
      )
    }

    @objc private func share(_ sender: Any?) {
      guard let selectedRange = model.selectedRange else {
        return
      }

      let attributedText = model.attributedText(in: selectedRange)
      let itemSource = TextActivityItemSource(attributedString: attributedText)

      let activityViewController = UIActivityViewController(
        activityItems: [itemSource],
        applicationActivities: nil
      )

      if let popover = activityViewController.popoverPresentationController {
        let rect =
          model.selectionRects(for: selectedRange)
          .last?.rect.integral ?? .zero
        popover.sourceView = self
        popover.sourceRect = rect
      }

      if let windowScene = window?.windowScene,
        let viewController = windowScene.windows.first?.rootViewController
      {
        viewController.present(activityViewController, animated: true)
      }
    }
  }

  extension UITextInteractionView: UITextInteractionDelegate {
    func interactionShouldBegin(_ interaction: UITextInteraction, at point: CGPoint) -> Bool {
      logger.debug("interactionShouldBegin(at: \(point.logDescription)) -> true")
      return true
    }

    func interactionWillBegin(_ interaction: UITextInteraction) {
      logger.debug("interactionWillBegin")
      _ = self.becomeFirstResponder()
    }

    func interactionDidEnd(_ interaction: UITextInteraction) {
      logger.debug("interactionDidEnd")
    }
  }

  extension UITextInteractionView: @MainActor UIEditMenuInteractionDelegate {
    func editMenuInteraction(
      _ interaction: UIEditMenuInteraction,
      menuFor configuration: UIEditMenuConfiguration,
      suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
      guard let selectedTextRange else { return nil }
      return editMenu(for: selectedTextRange, suggestedActions: suggestedActions)
        ?? UIMenu(children: suggestedActions)
    }
  }

  extension Logger.Textual.Category {
    fileprivate static let textInteraction = Self(rawValue: "textInteraction")
  }
#endif
