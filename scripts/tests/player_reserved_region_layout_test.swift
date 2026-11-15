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

func checkBarsInside(
    _ result: PlayerReservedRegionLayout.Result,
    _ context: PlayerReservedRegionLayout.Context,
    _ message: String
) {
    check(result.topBarOffset + context.topBarHeight <= context.bounds.height + 0.001, "\(message) top bar inside")
    check(result.bottomBarOffset + context.bottomBarHeight <= context.bounds.height + 0.001, "\(message) bottom bar inside")
    check(result.leadingInset + result.trailingInset <= context.bounds.width + 0.001, "\(message) horizontal inside")
}

func checkBarsSeparated(
    _ result: PlayerReservedRegionLayout.Result,
    _ context: PlayerReservedRegionLayout.Context,
    _ message: String
) {
    check(
        result.topBarOffset + context.topBarHeight <= context.bounds.height - context.bottomBarHeight - result.bottomBarOffset + 0.001,
        "\(message) bars separated"
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

        let foldTopContext = makeContext(division: [CGRect(x: 0, y: 100, width: 800, height: 20)])
        let foldTop = PlayerReservedRegionLayout.layout(context: foldTopContext)
        check(foldTop.topBarOffset == 120, "fold top offset: \(foldTop.topBarOffset)")
        check(foldTop.bottomBarOffset == 0, "fold top bottom")
        checkBarsInside(foldTop, foldTopContext, "fold top")
        checkBarsSeparated(foldTop, foldTopContext, "fold top")

        let foldBottomContext = makeContext(division: [CGRect(x: 0, y: 280, width: 800, height: 20)])
        let foldBottom = PlayerReservedRegionLayout.layout(context: foldBottomContext)
        check(foldBottom.bottomBarOffset == 120, "fold bottom offset: \(foldBottom.bottomBarOffset)")
        check(foldBottom.topBarOffset == 0, "fold bottom top")
        checkBarsInside(foldBottom, foldBottomContext, "fold bottom")
        checkBarsSeparated(foldBottom, foldBottomContext, "fold bottom")

        let cameraTopContext = makeContext(occlusion: [CGRect(x: 720, y: 0, width: 80, height: 40)])
        let cameraTop = PlayerReservedRegionLayout.layout(context: cameraTopContext)
        check(cameraTop.topBarOffset == 40, "camera top offset: \(cameraTop.topBarOffset)")
        checkBarsInside(cameraTop, cameraTopContext, "camera top")
        checkBarsSeparated(cameraTop, cameraTopContext, "camera top")

        let cameraBottomContext = makeContext(occlusion: [CGRect(x: 0, y: 360, width: 80, height: 40)])
        let cameraBottom = PlayerReservedRegionLayout.layout(context: cameraBottomContext)
        check(cameraBottom.bottomBarOffset == 40, "camera bottom offset: \(cameraBottom.bottomBarOffset)")
        checkBarsInside(cameraBottom, cameraBottomContext, "camera bottom")
        checkBarsSeparated(cameraBottom, cameraBottomContext, "camera bottom")

        let sideCameraLeftContext = makeContext(occlusion: [CGRect(x: 0, y: 0, width: 80, height: 400)])
        let sideCameraLeft = PlayerReservedRegionLayout.layout(context: sideCameraLeftContext)
        check(sideCameraLeft.leadingInset == 80, "side camera left leading: \(sideCameraLeft.leadingInset)")
        check(sideCameraLeft.topBarOffset == 0, "side camera left top: \(sideCameraLeft.topBarOffset)")
        check(sideCameraLeft.bottomBarOffset == 0, "side camera left bottom: \(sideCameraLeft.bottomBarOffset)")
        checkBarsInside(sideCameraLeft, sideCameraLeftContext, "side camera left")
        checkBarsSeparated(sideCameraLeft, sideCameraLeftContext, "side camera left")

        let sideCameraRightContext = makeContext(occlusion: [CGRect(x: 720, y: 0, width: 80, height: 400)])
        let sideCameraRight = PlayerReservedRegionLayout.layout(context: sideCameraRightContext)
        check(sideCameraRight.trailingInset == 80, "side camera right trailing: \(sideCameraRight.trailingInset)")
        check(sideCameraRight.topBarOffset == 0, "side camera right top: \(sideCameraRight.topBarOffset)")
        check(sideCameraRight.bottomBarOffset == 0, "side camera right bottom: \(sideCameraRight.bottomBarOffset)")
        checkBarsInside(sideCameraRight, sideCameraRightContext, "side camera right")
        checkBarsSeparated(sideCameraRight, sideCameraRightContext, "side camera right")

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
