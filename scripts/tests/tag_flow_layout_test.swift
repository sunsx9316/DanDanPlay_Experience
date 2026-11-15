import CoreGraphics
import Foundation

func check(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError("FAIL: \(message)")
    }
}

func checkFrame(_ frame: CGRect, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, _ message: String) {
    check(abs(frame.origin.x - x) < 0.001, "\(message) x: \(frame.origin.x) != \(x)")
    check(abs(frame.origin.y - y) < 0.001, "\(message) y: \(frame.origin.y) != \(y)")
    check(abs(frame.width - width) < 0.001, "\(message) width: \(frame.width) != \(width)")
    check(abs(frame.height - height) < 0.001, "\(message) height: \(frame.height) != \(height)")
}

@main
struct TagFlowLayoutTests {
    static func main() {
        let metrics = TagFlowLayout.Metrics(horizontalSpacing: 8, verticalSpacing: 6)

        let oneRow = TagFlowLayout.layout(
            sizes: [CGSize(width: 100, height: 20), CGSize(width: 80, height: 24)],
            in: 200,
            metrics: metrics
        )
        check(oneRow.frames.count == 2, "one row count")
        checkFrame(oneRow.frames[0], x: 0, y: 0, width: 100, height: 20, "row 1 item 1")
        checkFrame(oneRow.frames[1], x: 108, y: 0, width: 80, height: 24, "row 1 item 2")
        check(abs(oneRow.contentHeight - 24) < 0.001, "one row height")

        let twoRows = TagFlowLayout.layout(
            sizes: [CGSize(width: 100, height: 20), CGSize(width: 80, height: 24)],
            in: 150,
            metrics: metrics
        )
        checkFrame(twoRows.frames[0], x: 0, y: 0, width: 100, height: 20, "row 2 item 1")
        checkFrame(twoRows.frames[1], x: 0, y: 26, width: 80, height: 24, "row 2 item 2")
        check(abs(twoRows.contentHeight - 50) < 0.001, "two row height")

        let overWide = TagFlowLayout.layout(
            sizes: [CGSize(width: 100, height: 20), CGSize(width: 80, height: 24)],
            in: 50,
            metrics: metrics
        )
        checkFrame(overWide.frames[0], x: 0, y: 0, width: 100, height: 20, "overwide item 1")
        checkFrame(overWide.frames[1], x: 0, y: 26, width: 80, height: 24, "overwide item 2")

        let rtl = TagFlowLayout.layout(
            sizes: [CGSize(width: 100, height: 20), CGSize(width: 80, height: 24)],
            in: 200,
            metrics: metrics,
            layoutDirection: .rightToLeft
        )
        checkFrame(rtl.frames[0], x: 100, y: 0, width: 100, height: 20, "rtl item 1")
        checkFrame(rtl.frames[1], x: 12, y: 0, width: 80, height: 24, "rtl item 2")

        let varyingHeights = TagFlowLayout.layout(
            sizes: [CGSize(width: 50, height: 20), CGSize(width: 60, height: 40)],
            in: 200,
            metrics: metrics
        )
        checkFrame(varyingHeights.frames[0], x: 0, y: 0, width: 50, height: 20, "varying item 1")
        checkFrame(varyingHeights.frames[1], x: 58, y: 0, width: 60, height: 40, "varying item 2")
        check(abs(varyingHeights.contentHeight - 40) < 0.001, "varying row height")

        let empty = TagFlowLayout.layout(sizes: [], in: 200, metrics: metrics)
        check(empty.frames.isEmpty && empty.contentHeight == 0, "empty")
        let zeroWidth = TagFlowLayout.layout(sizes: [CGSize(width: 10, height: 10)], in: 0, metrics: metrics)
        check(zeroWidth.frames.isEmpty && zeroWidth.contentHeight == 0, "zero width")

        print("TagFlowLayout tests passed")
    }
}
