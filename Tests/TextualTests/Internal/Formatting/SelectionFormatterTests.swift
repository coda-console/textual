import Foundation
import Testing

@testable import Textual

struct SelectionFormatterTests {
  private func selected(_ markdown: String, text: String) throws -> Textual.Formatter {
    let source = try NSAttributedString(markdown: markdown)
    let range = (source.string as NSString).range(of: text)
    try #require(range.location != NSNotFound)
    return Formatter(selection: source.attributedSubstring(from: range))
  }

  @Test(arguments: ["1. 早上好", "7. 早上好", "- 早上好", "1. 外层\n   - 早上好"])
  func oneItem(markdown: String) throws {
    let formatter = try selected(markdown, text: "早上好")
    #expect(formatter.plainText() == "早上好")
    #expect(formatter.html() == "<p>&#26089;&#19978;&#22909;</p>")
  }

  @Test func partialItemKeepsInlineFormatting() throws {
    let formatter = try selected("1. 前文 **早上好** [朋友](https://example.com) 后文", text: "早上好 朋友")
    #expect(formatter.plainText() == "早上好 朋友")
    #expect(
      formatter.html()
        == "<p><strong>&#26089;&#19978;&#22909;</strong> <a href=\"https://example.com\">&#26379;&#21451;</a></p>")
  }

  @Test func literalNumberIsNotStripped() throws {
    let formatter = try selected("- `1. 早上好`", text: "1. 早上好")
    #expect(formatter.plainText() == "1. 早上好")
    #expect(formatter.html() == "<p><code>1. &#26089;&#19978;&#22909;</code></p>")
  }

  @Test func multipleItemsKeepTheirMarkers() throws {
    let source = try NSAttributedString(markdown: "7. 早上好\n8. 晚上好")
    let formatter = Formatter(selection: source)
    #expect(formatter.plainText() == "  7. 早上好\n  8. 晚上好")
    #expect(formatter.html().contains("<ol start=\"7\">"))
    let unordered = Formatter(selection: try NSAttributedString(markdown: "- 早上好\n- 晚上好"))
    #expect(unordered.plainText() == "  • 早上好\n  • 晚上好")
    #expect(unordered.html().contains("<ul>"))
  }

  @Test func nestedSiblingsKeepOnlyTheirOwnMarkers() throws {
    let formatter = try selected("1. 外层\n   - 早上好\n   - 晚上好", text: "早上好晚上好")
    #expect(formatter.plainText() == "  • 早上好\n  • 晚上好")
    #expect(!formatter.html().contains("<ol"))
    #expect(formatter.html().contains("<ul>"))
  }

  @Test func paragraphsWithinOneItemKeepTheirBreaks() throws {
    let source = try NSAttributedString(markdown: "1. 早上好\n\n   晚上好")
    let formatter = Formatter(selection: source)
    #expect(formatter.plainText() == "早上好\n\n晚上好")
  }

  @Test func documentExportKeepsSingleItemMarker() throws {
    let formatter = Formatter(try NSAttributedString(markdown: "1. 早上好"))
    #expect(formatter.plainText() == "  1. 早上好")
    #expect(formatter.html().contains("<ol>"))
  }
}
