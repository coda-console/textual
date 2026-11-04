#if os(macOS)
  import AppKit
  import SwiftUI
  import Testing
  @testable import Textual

  @MainActor
  struct TableLayoutTests {
    private final class Measurements {
      var cells: [StructuredText.TableCell.Identifier: CGRect] = [:]
      var text: [CGRect] = []
      var lineCounts: [Int] = []
    }

    // These widths straddle line breaks where Grid measures a narrower cell than it places.
    @Test(arguments: [603.0, 605.0, 616.0, 618.0, 634.0, 636.0, 640.0], [17.0, 18.0])
    func wrappedGitHubRows(width: CGFloat, fontSize: CGFloat) throws {
      let measurements = Measurements()
      let host = NSHostingView(
        rootView:
          StructuredText(
            markdown: """
              | 假设 | 所以这样做 | 假设不成立时 |
              | --- | --- | --- |
              | ① 可重导：坏了能从原始块再导一遍 | 删 TiDB 不算丢数据，湖里有就能删；湖不另做备份；重建只要最终一致 | 要备份、双份校验、删除强一致 |
              | ② 按块高顺序产生和消费 | 边界只要一条块高线；历史按 bundle 批量读写 | 历史要留在线索引 |
              | ③ 历史基本不改，要改就整个 bundle 换版本 | 版本用哈希和指针表示，靠状态判断，不用锁 | 要锁和跨系统协调 |
              | ④ 在线需求只看近期，按自然日、自然周统计 | 窗口取 8 天；更早的去湖里批量查 | 只是调窗口，机制不变 |
              """
          )
          .textual.structuredTextStyle(.gitHub)
          .font(.system(size: fontSize))
          .lineSpacing(8)
          .textual.textSelection(.enabled)
          .environment(\.colorScheme, .dark)
          .overlayPreferenceValue(StructuredText.TableCell.BoundsKey.self) { cells in
            GeometryReader { geometry in
              captureCells(cells.mapValues { geometry[$0] }, into: measurements)
            }
          }
          .overlayPreferenceValue(Text.LayoutKey.self) { layouts in
            GeometryReader { geometry in
              captureText(layouts, geometry: geometry, into: measurements)
            }
          }
          .frame(width: width)
          .fixedSize(horizontal: false, vertical: true)
      )
      let window = NSWindow(
        contentRect: CGRect(x: 0, y: 0, width: width, height: 800),
        styleMask: [.borderless], backing: .buffered, defer: false
      )
      window.isReleasedWhenClosed = false
      window.contentView = host
      defer { window.contentView = nil }
      host.layoutSubtreeIfNeeded()
      let layout = StructuredText.TableLayout(measurements.cells)
      try #require(layout.numberOfRows == 5)
      try #require(measurements.text.count == 15)
      for row in layout.rowIndices.dropLast() {
        #expect(layout.rowBounds(row + 1).minY - layout.rowBounds(row).maxY == 1)
      }
      for (index, bounds) in measurements.text.enumerated() {
        #expect(layout.rowBounds(index / 3).contains(bounds))
      }
      #expect(layout.horizontalDividers().count == 4)
      #expect(layout.horizontalDividers().allSatisfy { $0.height == 1 })
      if width == 634 && fontSize == 18 {
        // Both leading cells in rows ② and ③ must actually wrap in the reproducer.
        for index in [6, 7, 9, 10] {
          #expect(measurements.lineCounts[index] == 2)
        }
      }
    }

    private func captureCells(
      _ cells: [StructuredText.TableCell.Identifier: CGRect], into measurements: Measurements
    ) -> some View {
      measurements.cells = cells
      return Color.clear
    }

    private func captureText(
      _ layouts: Text.LayoutKey.Value, geometry: GeometryProxy, into measurements: Measurements
    ) -> some View {
      measurements.text = layouts.map { anchored in
        let origin = geometry[anchored.origin]
        return anchored.layout.map(\.typographicBounds.rect).reduce(CGRect.null, CGRectUnion)
          .offsetBy(dx: origin.x, dy: origin.y)
      }
      measurements.lineCounts = layouts.map { $0.layout.count }
      return Color.clear
    }
  }
#endif
