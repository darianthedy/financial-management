import SwiftUI

// Sheets that survive a fold (iPhone Duo design §5.1, implementation plan D5.1).
//
// A fold / unfold can re-create the whole screen: `SplitRootContainer`, the
// More ⇄ sidebar swap in `ContentRootView` and `.splitDetail` all branch on size
// class. A plain `.sheet` on such a screen goes with it, and its draft is lost.
// So the screen hands its sheet to a `FoldSafeSheetHost`, which `ContentRootView`
// presents from above every branch.
//
// - The sheet's content is captured when it opens, like a form's initial
//   values. Show read-only, live content (Summary) with a plain `.sheet`.
// - Sheets opened from inside a sheet need none of this: a sheet is never in a
//   size-class branch, so they stay plain `.sheet`s.

/// How a sheet sizes itself on the inner display. No effect on iPhone.
enum DuoSheetSizing {
    /// A centered card, for short forms.
    case form
    /// A large card, for long forms (Filters, Virtual installment).
    case page
}

extension View {
    /// Applies `sizing`, for sheets that aren't presented by `.foldSafeSheet`.
    @ViewBuilder
    func duoSheetSizing(_ sizing: DuoSheetSizing = .form) -> some View {
        switch sizing {
        case .form: presentationSizing(.form)
        case .page: presentationSizing(.page)
        }
    }
}

/// The sheet on screen, owned above every size-class branch.
@MainActor
@Observable
final class FoldSafeSheetHost {
    struct Presentation: Identifiable {
        let id = UUID()
        let owner: UUID
        let content: AnyView
        let onClose: () -> Void
    }

    private(set) var presentation: Presentation?
    /// Counts sheets that closed after a fold replaced the screen that opened
    /// them. Their `onSaved` reloaded that old screen, so the new one must
    /// reload itself (`.reloadsAfterFoldedSheet`).
    private(set) var foldedSheetsClosed = 0
    private var ownerWasReplaced = false

    func present(owner: UUID, content: AnyView, onClose: @escaping () -> Void) {
        presentation = Presentation(owner: owner, content: content, onClose: onClose)
        ownerWasReplaced = false
    }

    /// The owner cleared its own binding.
    func dismiss(owner: UUID) {
        guard presentation?.owner == owner else { return }
        presentation = nil
    }

    /// The owner left the hierarchy. The sheet stays: this is the fold.
    func ownerDisappeared(_ owner: UUID) {
        if presentation?.owner == owner { ownerWasReplaced = true }
    }

    /// The sheet closed itself (`dismiss()`, or a swipe down).
    func sheetClosed() {
        guard let closed = presentation else { return }
        presentation = nil
        closed.onClose()
        if ownerWasReplaced { foldedSheetsClosed += 1 }
    }
}

extension EnvironmentValues {
    @Entry var foldSafeSheetHost: FoldSafeSheetHost? = nil
}

extension View {
    /// Presents this tree's fold-safe sheets. Apply once, above every
    /// size-class branch.
    func hostsFoldSafeSheets() -> some View {
        modifier(FoldSafeSheetHostModifier())
    }

    /// `.sheet(item:)` whose draft survives a fold. Outside a host (e.g. a
    /// layout test) it is a plain `.sheet`.
    func foldSafeSheet<Item: Identifiable, Sheet: View>(
        item: Binding<Item?>,
        sizing: DuoSheetSizing = .form,
        @ViewBuilder content: @escaping (Item) -> Sheet
    ) -> some View {
        modifier(FoldSafeSheetModifier(item: item, sizing: sizing, sheet: content))
    }

    /// `.sheet(isPresented:)` whose draft survives a fold.
    func foldSafeSheet<Sheet: View>(
        isPresented: Binding<Bool>,
        sizing: DuoSheetSizing = .form,
        @ViewBuilder content: @escaping () -> Sheet
    ) -> some View {
        foldSafeSheet(
            item: Binding(
                get: { isPresented.wrappedValue ? PresentedFlag() : nil },
                set: { isPresented.wrappedValue = $0 != nil }
            ),
            sizing: sizing
        ) { _ in content() }
    }

    /// Reloads a screen with no realtime subscription when a sheet opened by
    /// the screen it replaced closes.
    func reloadsAfterFoldedSheet(_ reload: @escaping () async -> Void) -> some View {
        modifier(FoldedSheetReloadModifier(reload: reload))
    }
}

private struct PresentedFlag: Identifiable {
    let id = 0
}

private struct FoldSafeSheetHostModifier: ViewModifier {
    @State private var host = FoldSafeSheetHost()

    func body(content: Content) -> some View {
        // Read here so observation re-evaluates this body when it changes.
        let presentation = host.presentation
        content
            .environment(\.foldSafeSheetHost, host)
            .sheet(item: Binding(
                get: { presentation },
                set: { if $0 == nil { host.sheetClosed() } }
            )) { $0.content }
    }
}

private struct FoldSafeSheetModifier<Item: Identifiable, Sheet: View>: ViewModifier {
    @Environment(\.foldSafeSheetHost) private var host
    @Binding var item: Item?
    let sizing: DuoSheetSizing
    let sheet: (Item) -> Sheet

    /// Tells this screen's sheets from those of the screen it replaced.
    @State private var owner = UUID()

    init(item: Binding<Item?>, sizing: DuoSheetSizing, sheet: @escaping (Item) -> Sheet) {
        _item = item
        self.sizing = sizing
        self.sheet = sheet
    }

    func body(content: Content) -> some View {
        if let host {
            content
                .onChange(of: item?.id) { sync(host) }
                .onDisappear { host.ownerDisappeared(owner) }
        } else {
            content.sheet(item: $item) { sheet($0).duoSheetSizing(sizing) }
        }
    }

    private func sync(_ host: FoldSafeSheetHost) {
        guard let item else {
            host.dismiss(owner: owner)
            return
        }
        let binding = $item
        host.present(
            owner: owner,
            content: AnyView(sheet(item).duoSheetSizing(sizing)),
            onClose: { binding.wrappedValue = nil }
        )
    }
}

private struct FoldedSheetReloadModifier: ViewModifier {
    @Environment(\.foldSafeSheetHost) private var host
    let reload: () async -> Void

    func body(content: Content) -> some View {
        content.onChange(of: host?.foldedSheetsClosed) {
            Task { await reload() }
        }
    }
}
