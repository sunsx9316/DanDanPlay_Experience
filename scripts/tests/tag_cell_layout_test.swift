import CoreGraphics
import Foundation

func check(_ condition: Bool, _ message: String) {
    guard condition else { fatalError("FAIL: \(message)") }
}

@main
struct TagCellLayoutTests {
    static func main() {
        check(TagCellLayout.contentWidth(targetWidth: 400, contentViewWidth: 0, leftMargin: 15, rightMargin: 15) == 370, "target fallback")
        check(TagCellLayout.contentWidth(targetWidth: 400, contentViewWidth: 400, leftMargin: 15, rightMargin: 15) == 370, "content view full width")
        check(TagCellLayout.contentWidth(targetWidth: 400, contentViewWidth: 312, leftMargin: 59, rightMargin: 59) == 194, "content view safe-area width")
        check(TagCellLayout.contentWidth(targetWidth: 400, contentViewWidth: 0, leftMargin: 300, rightMargin: 300) == 0, "margins larger than width")
        check(TagCellLayout.contentWidth(targetWidth: 0, contentViewWidth: 0, leftMargin: 0, rightMargin: 0) == 0, "zero width")
        print("TagCellLayout tests passed")
    }
}
