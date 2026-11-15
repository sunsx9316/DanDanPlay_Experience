import CoreGraphics
import Foundation

func check(_ condition: Bool, _ message: String) {
    guard condition else { fatalError("FAIL: \(message)") }
}

@main
struct PlayerControlPanelLayoutTests {
    static func main() {
        check(PlayerControlPanelLayout.width(containerWidth: 1000) == 420, "max width")
        check(PlayerControlPanelLayout.width(containerWidth: 800) == 400, "ratio width")
        check(PlayerControlPanelLayout.width(containerWidth: 390) == 320, "min width")
        check(PlayerControlPanelLayout.width(containerWidth: 320) == 320, "exact min width")
        check(PlayerControlPanelLayout.width(containerWidth: 200) == 200, "narrow container")
        check(PlayerControlPanelLayout.width(containerWidth: 0) == 0, "zero container")

        for containerWidth in [100.0, 200.0, 320.0, 390.0, 800.0, 1000.0] as [CGFloat] {
            check(
                PlayerControlPanelLayout.width(containerWidth: containerWidth) <= containerWidth,
                "panel must not exceed container at \(containerWidth)"
            )
        }

        print("PlayerControlPanelLayout tests passed")
    }
}
