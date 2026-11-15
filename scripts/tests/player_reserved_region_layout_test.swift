import CoreGraphics
import Foundation

func check(_ condition: Bool, _ message: String) {
    guard condition else { fatalError("FAIL: \(message)") }
}

func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 800, height: 400),
    division: [CGRect] = [],
    occlusion: [CGRect] = [],
    topBarHeight: CGFloat = 80,
    bottomBarHeight: CGFloat = 80,
    gap: CGFloat = 0
) -> PlayerReservedRegionLayout.Context {
    .init(
        bounds: bounds,
        divisionRegions: division,
        occlusionRegions: occlusion,
        topBarHeight: topBarHeight,
        bottomBarHeight: bottomBarHeight,
        gap: gap
    )
}

@main
struct PlayerReservedRegionLayoutTests {
    static func main() {
        let none = PlayerReservedRegionLayout.layout(context: makeContext())
        check(none == .init(topBarOffset: 0, bottomBarOffset: 0, leadingInset: 0, trailingInset: 0), "none")

        let foldLeft = PlayerReservedRegionLayout.layout(
            context: makeContext(division: [CGRect(x: 100, y: 0, width: 20, height: 400)])
        )
        check(foldLeft.leadingInset == 120, "fold left leading: \(foldLeft.leadingInset)")
        check(foldLeft.trailingInset == 0, "fold left trailing")

        let foldRight = PlayerReservedRegionLayout.layout(
            context: makeContext(division: [CGRect(x: 680, y: 0, width: 20, height: 400)])
        )
        check(foldRight.trailingInset == 120, "fold right trailing: \(foldRight.trailingInset)")
        check(foldRight.leadingInset == 0, "fold right leading")

        let foldTop = PlayerReservedRegionLayout.layout(
            context: makeContext(division: [CGRect(x: 0, y: 100, width: 800, height: 20)])
        )
        check(foldTop.topBarOffset == 120, "fold top offset: \(foldTop.topBarOffset)")
        check(foldTop.bottomBarOffset == 0, "fold top bottom")

        let foldBottom = PlayerReservedRegionLayout.layout(
            context: makeContext(division: [CGRect(x: 0, y: 280, width: 800, height: 20)])
        )
        check(foldBottom.bottomBarOffset == 120, "fold bottom offset: \(foldBottom.bottomBarOffset)")
        check(foldBottom.topBarOffset == 0, "fold bottom top")

        let cameraTop = PlayerReservedRegionLayout.layout(
            context: makeContext(occlusion: [CGRect(x: 720, y: 0, width: 80, height: 40)])
        )
        check(cameraTop.topBarOffset == 40, "camera top offset: \(cameraTop.topBarOffset)")

        let cameraBottom = PlayerReservedRegionLayout.layout(
            context: makeContext(occlusion: [CGRect(x: 0, y: 360, width: 80, height: 40)])
        )
        check(cameraBottom.bottomBarOffset == 40, "camera bottom offset: \(cameraBottom.bottomBarOffset)")

        let combined = PlayerReservedRegionLayout.layout(
            context: makeContext(
                division: [CGRect(x: 100, y: 0, width: 20, height: 400)],
                occlusion: [CGRect(x: 720, y: 0, width: 80, height: 40)]
            )
        )
        check(combined.leadingInset == 120, "combined leading")
        check(combined.topBarOffset == 40, "combined top")

        print("PlayerReservedRegionLayout tests passed")
    }
}
