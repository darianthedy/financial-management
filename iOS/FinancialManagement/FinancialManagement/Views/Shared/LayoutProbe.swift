import SwiftUI

extension View {
    /// Records this view's frame under `id` for layout tests (iPhone Duo plan
    /// D0.3). Mark tappable controls `interactive` so the harness can assert
    /// they stay clear of the vertical bar rail and the fold. No-op in Release.
    func layoutProbe(_ id: String, interactive: Bool = false) -> some View {
        modifier(LayoutProbeModifier(id: id, interactive: interactive))
    }
}

private struct LayoutProbeModifier: ViewModifier {
    let id: String
    let interactive: Bool

    func body(content: Content) -> some View {
        #if DEBUG
        content.background {
            GeometryReader { geo in
                let frame = geo.frame(in: .global)
                Color.clear
                    .onAppear { LayoutProbeRecorder.shared.record(id, frame, interactive: interactive) }
                    .onChange(of: frame) { LayoutProbeRecorder.shared.record(id, frame, interactive: interactive) }
                    .onDisappear { LayoutProbeRecorder.shared.remove(id, frame) }
            }
        }
        #else
        content
        #endif
    }
}

#if DEBUG
/// Collects `.layoutProbe` frames (window coordinates) while a layout test
/// renders a screen. Recording is off unless a test turns it on.
@MainActor
final class LayoutProbeRecorder {
    struct Record: Equatable {
        var frame: CGRect
        var interactive: Bool
    }

    static let shared = LayoutProbeRecorder()

    var isRecording = false
    /// Drop a probe's record when its view disappears, for tests that ask
    /// what is on screen now rather than what was shown.
    var dropsDisappeared = false
    private(set) var records: [String: Record] = [:]

    func reset() { records = [:] }

    /// A probe left the screen. Only its own record goes: another view may
    /// have recorded the same ID since (a re-created screen).
    func remove(_ id: String, _ frame: CGRect) {
        guard isRecording, dropsDisappeared, records[id]?.frame == frame else { return }
        records[id] = nil
    }

    func record(_ id: String, _ frame: CGRect, interactive: Bool) {
        guard isRecording else { return }
        records[id] = Record(frame: frame, interactive: interactive)
    }
}
#endif
