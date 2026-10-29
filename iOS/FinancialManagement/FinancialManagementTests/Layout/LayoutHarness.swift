import SwiftUI
import UIKit
import XCTest
@testable import FinancialManagement

/// One of the standard iPhone Duo layout sizes (implementation plan D0.3), with
/// the safe area the probe measured for it.
struct LayoutSize: CustomStringConvertible {
    let name: String
    let size: CGSize
    let horizontal: UserInterfaceSizeClass
    let vertical: UserInterfaceSizeClass
    let safeArea: UIEdgeInsets

    var description: String { name }

    /// Outer display, portrait: 466 × 678, of which 382 pt is content (the
    /// right 84 pt is the status-bar/tab-bar rail).
    static let outerPortrait = LayoutSize(
        name: "outer-portrait", size: CGSize(width: 466, height: 678),
        horizontal: .compact, vertical: .regular,
        safeArea: UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 84)
    )
    /// Inner display, landscape (native): 951 × 669.
    static let innerLandscape = LayoutSize(
        name: "inner-landscape", size: CGSize(width: 951, height: 669),
        horizontal: .regular, vertical: .regular, safeArea: .zero
    )
    /// Inner display, portrait: 669 × 951.
    static let innerPortrait = LayoutSize(
        name: "inner-portrait", size: CGSize(width: 669, height: 951),
        horizontal: .regular, vertical: .regular, safeArea: .zero
    )
    /// Split View at half the inner display's width: ~475 wide, compact.
    static let splitHalf = LayoutSize(
        name: "split-half", size: CGSize(width: 475, height: 669),
        horizontal: .compact, vertical: .regular, safeArea: .zero
    )

    static let all: [LayoutSize] = [.outerPortrait, .innerLandscape, .innerPortrait, .splitHalf]

    /// The narrowest content width the app must support (outer portrait).
    static let minimumCompactContentWidth: CGFloat = 382

    /// The rectangles inside the window that system bars occupy (the outer
    /// display's vertical rail), in the hosted view's coordinates.
    var unsafeRects: [CGRect] {
        var rects: [CGRect] = []
        if safeArea.right > 0 {
            rects.append(CGRect(x: size.width - safeArea.right, y: 0, width: safeArea.right, height: size.height))
        }
        if safeArea.left > 0 {
            rects.append(CGRect(x: 0, y: 0, width: safeArea.left, height: size.height))
        }
        return rects
    }
}

/// What a hosted render produced: the probed frames (in the hosted view's
/// coordinates), a screenshot, and the size it was rendered at.
struct LayoutSnapshot {
    let size: LayoutSize
    let fold: FoldContext
    let frames: [String: LayoutProbeRecorder.Record]
    /// Accessibility labels of every visible UIKit view, e.g. system tab bar
    /// items and sidebar rows, which `.layoutProbe` can't reach.
    let labels: Set<String>
    /// Visible `UITab` titles in order, depth-first (a section's title, then
    /// its tabs), from the tab bar controller SwiftUI's `TabView` is built on.
    let tabTitles: [String]
    let image: UIImage

    func frame(_ id: String, file: StaticString = #filePath, line: UInt = #line) throws -> CGRect {
        try XCTUnwrap(frames[id]?.frame, "No layout probe '\(id)' at \(size)", file: file, line: line)
    }
}

/// Hosts any SwiftUI view in a window at a `LayoutSize`, with size-class trait
/// overrides, the size's safe area, and an injected `FoldContext`, then
/// collects `.layoutProbe` frames and a screenshot. Builds on DuoProbeTests,
/// but renders in-process with fixture data — no relaunch, login or network.
@MainActor
enum LayoutHarness {
    /// Renders `view` and waits until `ready` holds for the recorded frames
    /// (e.g. a probe that only appears once data has loaded), or `timeout`.
    static func render<V: View>(
        _ view: V,
        at size: LayoutSize,
        fold: FoldContext = .none,
        timeout: Duration = .seconds(10),
        until ready: ([String: LayoutProbeRecorder.Record]) -> Bool = { _ in true }
    ) async throws -> LayoutSnapshot {
        let recorder = LayoutProbeRecorder.shared
        recorder.reset()
        recorder.isRecording = true
        defer { recorder.isRecording = false }

        let root = view
            .environment(\.horizontalSizeClass, size.horizontal)
            .environment(\.verticalSizeClass, size.vertical)
            .environment(\.foldContext, fold)
        let host = UIHostingController(rootView: root)
        host.traitOverrides.horizontalSizeClass = size.horizontal == .regular ? .regular : .compact
        host.traitOverrides.verticalSizeClass = size.vertical == .regular ? .regular : .compact

        let window = UIWindow(windowScene: try activeScene())
        window.frame = CGRect(origin: .zero, size: size.size)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        // Top up the device's real safe area to the size's, so every size
        // gets the same insets no matter which display the simulator is on.
        window.layoutIfNeeded()
        host.additionalSafeAreaInsets = topUp(size.safeArea, from: window.safeAreaInsets)

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
            if ready(recorder.records) { break }
        }
        // One more pass so animations triggered by the data settle.
        try await Task.sleep(for: .milliseconds(400))
        window.layoutIfNeeded()

        let origin = host.view.convert(CGPoint.zero, to: window)
        let frames = recorder.records.mapValues { record in
            var local = record
            local.frame = record.frame.offsetBy(dx: -origin.x, dy: -origin.y)
            return local
        }
        let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        return LayoutSnapshot(
            size: size, fold: fold, frames: frames, labels: labels(in: window),
            tabTitles: tabTitles(in: window), image: image
        )
    }

    /// Labels from three sources, because system bars aren't plain labelled
    /// UIViews: view `accessibilityLabel`s, the accessibility element tree
    /// (where SwiftUI and the Liquid Glass tab bar expose their items), and the
    /// titles of the visible `UITab`s of any tab bar controller.
    private static func labels(in window: UIWindow) -> Set<String> {
        var out: Set<String> = []
        var seen: Set<ObjectIdentifier> = []

        func visit(_ object: NSObject, depth: Int) {
            guard depth < 80, out.count < 2000, seen.insert(ObjectIdentifier(object)).inserted else { return }
            if let view = object as? UIView, view.isHidden || view.alpha < 0.01 { return }
            if let label = object.accessibilityLabel, !label.isEmpty { out.insert(label) }
            if let elements = object.accessibilityElements {
                for case let element as NSObject in elements { visit(element, depth: depth + 1) }
            } else {
                let count = object.accessibilityElementCount()
                if count != NSNotFound, count > 0 {
                    for i in 0..<min(count, 500) {
                        if let element = object.accessibilityElement(at: i) as? NSObject { visit(element, depth: depth + 1) }
                    }
                }
            }
            if let view = object as? UIView {
                for sub in view.subviews { visit(sub, depth: depth + 1) }
            }
        }
        visit(window, depth: 0)

        out.formUnion(tabTitles(in: window))
        return out
    }

    private static func tabTitles(in window: UIWindow) -> [String] {
        var out: [String] = []
        func walk(_ tabs: [UITab]) {
            for tab in tabs where !tab.isHidden {
                out.append(tab.title)
                if let group = tab as? UITabGroup { walk(group.children) }
            }
        }
        func controllers(_ vc: UIViewController) {
            if let tabs = (vc as? UITabBarController)?.tabs { walk(tabs) }
            vc.children.forEach(controllers)
        }
        if let root = window.rootViewController { controllers(root) }
        return out
    }

    private static func topUp(_ wanted: UIEdgeInsets, from actual: UIEdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: max(0, wanted.top - actual.top),
            left: max(0, wanted.left - actual.left),
            bottom: max(0, wanted.bottom - actual.bottom),
            right: max(0, wanted.right - actual.right)
        )
    }

    private static func activeScene() throws -> UIWindowScene {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return try XCTUnwrap(
            scenes.first { $0.activationState == .foregroundActive } ?? scenes.first,
            "No window scene to host the layout test in"
        )
    }
}

// MARK: - Shared assertions

extension XCTestCase {
    /// Attaches the snapshot's screenshot to the result bundle.
    func attach(_ snapshot: LayoutSnapshot, name: String) {
        let attachment = XCTAttachment(image: snapshot.image)
        attachment.name = "\(name)-\(snapshot.size.name).png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// No interactive probe may overlap the vertical bar rail or the fold.
    func assertNoInteractiveOverlap(
        _ snapshot: LayoutSnapshot, file: StaticString = #filePath, line: UInt = #line
    ) {
        var forbidden = snapshot.size.unsafeRects.map { ("rail", $0) }
        if let fold = snapshot.fold.divisionRect(in: snapshot.size.size) {
            // A zero-width fold line still forbids anything crossing it.
            forbidden.append(("fold", fold.insetBy(dx: fold.width == 0 ? -0.5 : 0, dy: fold.height == 0 ? -0.5 : 0)))
        }
        for (id, record) in snapshot.frames where record.interactive {
            for (name, rect) in forbidden where record.frame.intersects(rect) {
                XCTFail(
                    "'\(id)' \(record.frame) overlaps the \(name) \(rect) at \(snapshot.size)",
                    file: file, line: line
                )
            }
        }
    }

    /// On compact sizes the screen must get at least the outer display's
    /// 382 pt of content width (or the full safe width, if narrower).
    func assertCompactContentWidth(
        _ snapshot: LayoutSnapshot, probe id: String,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        guard snapshot.size.horizontal == .compact else { return }
        let size = snapshot.size
        let safeWidth = size.size.width - size.safeArea.left - size.safeArea.right
        let expected = min(LayoutSize.minimumCompactContentWidth, safeWidth)
        let width = try snapshot.frame(id, file: file, line: line).width
        XCTAssertGreaterThanOrEqual(
            width, expected - 0.5,
            "'\(id)' is \(width) pt wide at \(size); needs ≥ \(expected)", file: file, line: line
        )
    }

    /// A list row (inset by the list's own margins) must stay inside the
    /// safe area: clear of the outer display's rail on either edge.
    func assertInsideSafeArea(
        _ snapshot: LayoutSnapshot, probe id: String,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let size = snapshot.size
        let frame = try snapshot.frame(id, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minX, size.safeArea.left - 0.5, "'\(id)' \(frame) starts in the rail at \(size)", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, size.size.width - size.safeArea.right + 0.5, "'\(id)' \(frame) runs into the rail at \(size)", file: file, line: line)
    }
}
