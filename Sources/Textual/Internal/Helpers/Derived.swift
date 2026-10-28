import Foundation

// A value a view derives from its inputs, made in the body pass that first needs it and kept until the
// inputs change. Held in `@State`, it is not view state: making it schedules no further update, so a new
// view draws its content in its first layout rather than in an empty one followed by a second pass.
@MainActor final class Derived<Key: Equatable, Value> {
  private var made: (key: Key, value: Value)?

  func callAsFunction(_ key: Key, make: () -> Value) -> Value {
    if let made, made.key == key { return made.value }
    let value = make()
    made = (key, value)
    return value
  }
}
