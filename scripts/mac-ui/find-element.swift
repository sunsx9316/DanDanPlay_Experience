import ApplicationServices
import Foundation

func stringAttr(_ element: AXUIElement, _ attr: String) -> String {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success else { return "" }
    if let string = value as? String { return string }
    if let number = value as? NSNumber { return number.stringValue }
    return ""
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
    return value as? [AXUIElement] ?? []
}

func actions(_ element: AXUIElement) -> [String] {
    var value: CFArray?
    guard AXUIElementCopyActionNames(element, &value) == .success else { return [] }
    return value as? [String] ?? []
}

func walk(_ element: AXUIElement, depth: Int, maxDepth: Int, match: (AXUIElement) -> Bool) -> Bool {
    if match(element) {
        let role = stringAttr(element, kAXRoleAttribute)
        let identifier = stringAttr(element, "AXIdentifier")
        let title = stringAttr(element, kAXTitleAttribute)
        let desc = stringAttr(element, kAXDescriptionAttribute)
        let value = stringAttr(element, kAXValueAttribute)
        print("FOUND depth=\(depth) role=\(role) id=\(identifier) title=\(title) desc=\(desc) value=\(value.prefix(80))")
        print("actions=\(actions(element).joined(separator: ","))")
        return true
    }
    guard depth < maxDepth else { return false }
    for child in children(element) {
        if walk(child, depth: depth + 1, maxDepth: maxDepth, match: match) { return true }
    }
    return false
}

guard CommandLine.arguments.count > 2, let pid = Int32(CommandLine.arguments[1]) else {
    print("usage: find-element.swift <pid> <identifier-or-title> [maxDepth]")
    exit(2)
}
let needle = CommandLine.arguments[2]
let maxDepth = CommandLine.arguments.count > 3 ? (Int(CommandLine.arguments[3]) ?? 12) : 12
let app = AXUIElementCreateApplication(pid)

var windowsRef: CFTypeRef?
guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success else {
    print("cannot read windows; check accessibility permission")
    exit(3)
}
let windows = windowsRef as? [AXUIElement] ?? []
for window in windows {
    if walk(window, depth: 0, maxDepth: maxDepth, match: { element in
        stringAttr(element, "AXIdentifier") == needle || stringAttr(element, kAXTitleAttribute) == needle
    }) {
        exit(0)
    }
}
print("not found: \(needle)")
exit(1)
