import SwiftUI
import UIKit
import XCTest

/// iPhone Duo layout probe (docs/ios-iphone-duo-plan.md §1.3). Not a
/// correctness test: it records what the system actually does on the current
/// display — point sizes, size classes, per-edge safe areas, and where system
/// bars and toolbar items land — so the plan's estimates can be replaced with
/// measurements. Each probe writes `<name>.json` + `<name>.png` to `DUO_OUT`
/// and attaches both to the result bundle.
///
/// Skipped unless `DUO_PROBE=1` (CI passes `TEST_RUNNER_DUO_PROBE=1`), so the
/// normal unit-test run is unaffected.
@MainActor
final class DuoProbeTests: XCTestCase {
    override func setUp() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["DUO_PROBE"] == "1",
            "Set DUO_PROBE=1 to run the iPhone Duo layout probe."
        )
    }

    func test1_environment() async throws {
        try await Task.sleep(for: .seconds(2))
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let report: [String: Any] = [
            "simulator": [
                "model": env("SIMULATOR_MODEL_IDENTIFIER"),
                "deviceName": env("SIMULATOR_DEVICE_NAME"),
                "runtime": env("SIMULATOR_RUNTIME_VERSION"),
            ],
            "systemVersion": UIDevice.current.systemVersion,
            "idiom": UIDevice.current.userInterfaceIdiom.rawValue,
            "screens": UIScreen.screens.map(describe(screen:)),
            "scenes": scenes.map(describe(scene:)),
        ]
        try write("environment", report, image: nil)
    }

    func test2_tabsPortrait() async throws {
        try await probe("tabs", ProbeTabs())
    }

    func test3_splitPortrait() async throws {
        try await probe("split", ProbeSplit())
    }

    func test4_sheetPortrait() async throws {
        try await probe("sheet", ProbeSheetHost(), settle: 3)
    }

    func test5_landscape() async throws {
        let scene = try activeScene()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { error in
            print("DUOPROBE landscape request error: \(error)")
        }
        try await Task.sleep(for: .seconds(3))
        try await probe("tabs-landscape", ProbeTabs())
        try await probe("split-landscape", ProbeSplit())
        try await probe("sheet-landscape", ProbeSheetHost(), settle: 3)
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
        try await Task.sleep(for: .seconds(2))
    }

    // MARK: - Probe runner

    private func probe<V: View>(_ name: String, _ view: V, settle: Double = 2) async throws {
        ProbeFrames.shared.reset()
        let scene = try activeScene()
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        try await Task.sleep(for: .seconds(settle))
        window.layoutIfNeeded()

        let report: [String: Any] = [
            "scene": describe(scene: scene),
            "window": describe(view: window, in: window),
            "windowSafeArea": insets(window.safeAreaInsets),
            "traits": describe(traits: window.traitCollection),
            "systemViews": systemViews(in: window),
            "labeledViews": labeledViews(in: window),
            "swiftUIFrames": ProbeFrames.shared.snapshot(),
        ]
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try write(name, report, image: image)
        window.isHidden = true
    }

    private func activeScene() throws -> UIWindowScene {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return try XCTUnwrap(
            scenes.first { $0.activationState == .foregroundActive } ?? scenes.first,
            "No window scene"
        )
    }

    // MARK: - Description helpers

    private func env(_ key: String) -> String {
        ProcessInfo.processInfo.environment[key] ?? ""
    }

    private func rect(_ r: CGRect) -> [String: Double] {
        ["x": r.minX, "y": r.minY, "w": r.width, "h": r.height]
    }

    private func insets(_ i: UIEdgeInsets) -> [String: Double] {
        ["top": i.top, "left": i.left, "bottom": i.bottom, "right": i.right]
    }

    private func sizeClass(_ c: UIUserInterfaceSizeClass) -> String {
        switch c {
        case .compact: "compact"
        case .regular: "regular"
        default: "unspecified"
        }
    }

    private func describe(traits t: UITraitCollection) -> [String: Any] {
        [
            "horizontal": sizeClass(t.horizontalSizeClass),
            "vertical": sizeClass(t.verticalSizeClass),
            "displayScale": t.displayScale,
            "idiom": t.userInterfaceIdiom.rawValue,
        ]
    }

    private func describe(screen s: UIScreen) -> [String: Any] {
        [
            "bounds": rect(s.bounds),
            "nativeBounds": rect(s.nativeBounds),
            "scale": s.scale,
            "nativeScale": s.nativeScale,
            "maxFPS": s.maximumFramesPerSecond,
            "traits": describe(traits: s.traitCollection),
            "description": String(describing: s),
        ]
    }

    private func describe(scene s: UIWindowScene) -> [String: Any] {
        [
            "role": s.session.role.rawValue,
            "activation": s.activationState.rawValue,
            "orientation": s.effectiveGeometry.interfaceOrientation.rawValue,
            "coordinateSpace": rect(s.effectiveGeometry.coordinateSpace.bounds),
            "screen": describe(screen: s.screen),
            "traits": describe(traits: s.traitCollection),
            "windows": s.windows.map { describe(view: $0, in: $0) },
        ]
    }

    private func describe(view v: UIView, in window: UIWindow) -> [String: Any] {
        [
            "class": String(describing: type(of: v)),
            "frame": rect(v.convert(v.bounds, to: window)),
            "safeArea": insets(v.safeAreaInsets),
            "hidden": v.isHidden,
        ]
    }

    /// System bar-like views (navigation bars, tab bars, toolbars, sidebars,
    /// and private platters/glass containers) with their window frames — the
    /// evidence for which edge vertical bars occupy.
    private func systemViews(in window: UIWindow) -> [[String: Any]] {
        let pattern = try? NSRegularExpression(
            pattern: "Bar|Sidebar|Toolbar|Tab|Navigation|Platter|Glass|Split|Column|Sheet|Presentation"
        )
        var out: [[String: Any]] = []
        walk(window, depth: 0) { view in
            let name = String(describing: type(of: view))
            guard out.count < 300,
                  view.bounds.width > 0, view.bounds.height > 0,
                  let pattern,
                  pattern.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)) != nil
            else { return }
            out.append(describe(view: view, in: window))
        }
        return out
    }

    /// Views carrying the accessibility labels the probe screens use, so each
    /// toolbar item, tab item, and sidebar row can be located on screen.
    private func labeledViews(in window: UIWindow) -> [[String: Any]] {
        var out: [[String: Any]] = []
        walk(window, depth: 0) { view in
            guard out.count < 300, let label = view.accessibilityLabel, !label.isEmpty,
                  ProbeLabels.all.contains(label)
            else { return }
            var entry = describe(view: view, in: window)
            entry["label"] = label
            out.append(entry)
        }
        return out
    }

    private func walk(_ view: UIView, depth: Int, _ visit: (UIView) -> Void) {
        guard depth < 40, !view.isHidden else { return }
        visit(view)
        for sub in view.subviews { walk(sub, depth: depth + 1, visit) }
    }

    // MARK: - Output

    private func write(_ name: String, _ report: [String: Any], image: UIImage?) throws {
        let json = try JSONSerialization.data(
            withJSONObject: report, options: [.prettyPrinted, .sortedKeys]
        )
        print("DUOPROBE \(name) \(String(decoding: json, as: UTF8.self))")

        let jsonAttachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        jsonAttachment.name = "\(name).json"
        jsonAttachment.lifetime = .keepAlways
        add(jsonAttachment)

        let dir = URL(fileURLWithPath: env("DUO_OUT").isEmpty ? NSTemporaryDirectory() : env("DUO_OUT"))
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? json.write(to: dir.appendingPathComponent("\(name).json"))

        if let image, let png = image.pngData() {
            let imageAttachment = XCTAttachment(image: image)
            imageAttachment.name = "\(name).png"
            imageAttachment.lifetime = .keepAlways
            add(imageAttachment)
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
        }
    }
}

// MARK: - Probe screens

/// Accessibility labels used by the probe screens.
private enum ProbeLabels {
    static let all: Set<String> = [
        "Dashboard", "Accounts", "Transactions", "Budgets", "More", "Tags", "Settings",
        "Add", "Filter", "Summary", "Edit", "Cancel", "Save", "Back", "Show Sidebar",
        "Hide Sidebar", "Sidebar",
    ]
}

/// Frames of probe SwiftUI views in global coordinates, with the safe-area
/// insets and size classes SwiftUI reported for them.
@MainActor
private final class ProbeFrames {
    static let shared = ProbeFrames()
    private var frames: [String: Any] = [:]

    func reset() { frames = [:] }
    func snapshot() -> [String: Any] { frames }

    func record(_ key: String, _ geo: GeometryProxy, h: UserInterfaceSizeClass?, v: UserInterfaceSizeClass?) {
        let f = geo.frame(in: .global)
        let s = geo.safeAreaInsets
        frames[key] = [
            "frame": ["x": f.minX, "y": f.minY, "w": f.width, "h": f.height],
            "safeArea": ["top": s.top, "leading": s.leading, "bottom": s.bottom, "trailing": s.trailing],
            "horizontal": h.map { $0 == .compact ? "compact" : "regular" } ?? "unspecified",
            "vertical": v.map { $0 == .compact ? "compact" : "regular" } ?? "unspecified",
        ]
    }
}

/// Reports its frame under `key` whenever it lays out.
private struct Probe: ViewModifier {
    let key: String
    @Environment(\.horizontalSizeClass) private var h
    @Environment(\.verticalSizeClass) private var v

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { ProbeFrames.shared.record(key, geo, h: h, v: v) }
                    .onChange(of: geo.size) { ProbeFrames.shared.record(key, geo, h: h, v: v) }
            }
        )
    }
}

private extension View {
    func probe(_ key: String) -> some View { modifier(Probe(key: key)) }
}

/// A list screen with the Transactions toolbar: Add (primary), Filter, Summary.
private struct ProbeScreen: View {
    let title: String

    var body: some View {
        NavigationStack {
            List(0..<30, id: \.self) { Text("\(title) row \($0)") }
                .probe("\(title).content")
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add", systemImage: "plus") {}
                    }
                    ToolbarItem {
                        Button("Filter", systemImage: "line.3.horizontal.decrease.circle") {}
                    }
                    ToolbarItem {
                        Button("Summary", systemImage: "chart.bar.xaxis") {}
                    }
                }
        }
    }
}

/// The plan's root (§3.1): adaptable tab bar → sidebar, with More only in the
/// tab bar and Management/Settings only in the sidebar.
private struct ProbeTabs: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "square.grid.2x2") { ProbeScreen(title: "Dashboard") }
            Tab("Accounts", systemImage: "wallet.bifold") { ProbeScreen(title: "Accounts") }
            Tab("Transactions", systemImage: "arrow.left.arrow.right") { ProbeScreen(title: "Transactions") }
            Tab("Budgets", systemImage: "target") { ProbeScreen(title: "Budgets") }
            Tab("More", systemImage: "ellipsis") { ProbeScreen(title: "More") }
                .defaultVisibility(.hidden, for: .sidebar)
            TabSection("Management") {
                Tab("Tags", systemImage: "tag") { ProbeScreen(title: "Tags") }
                    .defaultVisibility(.hidden, for: .tabBar)
                Tab("Settings", systemImage: "gear") { ProbeScreen(title: "Settings") }
                    .defaultVisibility(.hidden, for: .tabBar)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .probe("tabs.root")
    }
}

/// The plan's list → detail container (§3.2) with a selection.
private struct ProbeSplit: View {
    @State private var selection: Int? = 0

    var body: some View {
        NavigationSplitView {
            List(0..<12, id: \.self, selection: $selection) { Text("Account \($0)") }
                .probe("split.sidebar")
                .navigationTitle("Accounts")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Add", systemImage: "plus") {}
                    }
                }
        } detail: {
            Text("Account \(selection ?? -1) detail")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .probe("split.detail")
                .navigationTitle("Detail")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) { Button("Edit") {} }
                }
        }
        .probe("split.root")
    }
}

/// A form sheet with Cancel / Save, sized `.form` (§3.3, §5.1).
private struct ProbeSheetHost: View {
    @State private var showing = false

    var body: some View {
        Color(.systemBackground)
            .probe("sheet.parent")
            .task { showing = true }
            .sheet(isPresented: $showing) {
                NavigationStack {
                    Form {
                        TextField("Amount", text: .constant("150,000"))
                        Text("Account")
                        Text("Date")
                    }
                    .probe("sheet.content")
                    .navigationTitle("New Transaction")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") {} }
                        ToolbarItem(placement: .confirmationAction) { Button("Save") {} }
                    }
                }
                .presentationSizing(.form)
            }
    }
}
