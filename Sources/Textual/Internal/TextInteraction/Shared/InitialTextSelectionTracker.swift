#if TEXTUAL_ENABLE_TEXT_SELECTION
  import Foundation

  // MARK: - Overview
  //
  // `InitialTextSelectionTracker` holds an `InitialTextSelection` request until the selection
  // view can apply it, and makes sure each request `id` is consumed at most once per view so
  // later SwiftUI updates don't re-apply it over a selection the user has since changed.

  struct InitialTextSelectionTracker {
    private(set) var pending: InitialTextSelection?
    private var consumedIDs: Set<UUID> = []

    /// Replaces the pending request with the current one; `nil` or an already consumed request
    /// leaves nothing pending.
    mutating func update(_ request: InitialTextSelection?) {
      pending = request.flatMap { consumedIDs.contains($0.id) ? nil : $0 }
    }

    /// Consumes the pending request once the view is ready to apply it.
    ///
    /// Returns `nil` when there is no pending request, the view isn't ready yet (the request
    /// stays pending), or `contains` reports that the request's point is outside the view (the
    /// request is consumed so another view handles it).
    mutating func take(
      isReady: Bool,
      contains: (InitialTextSelection) -> Bool
    ) -> InitialTextSelection? {
      guard isReady, let pending else {
        return nil
      }
      consumedIDs.insert(pending.id)
      self.pending = nil
      return contains(pending) ? pending : nil
    }
  }
#endif
