import SwiftUI

/// A list's selection whose detail column is an **editor** (Scheduled in D2.6,
/// Transactions in D3.1): picking another row while the editor has unsaved
/// changes asks "Discard changes?" first, instead of silently dropping them.
///
/// The editor reports its dirty state into `isDirty`; rows call `request(_:)`;
/// the list shows `.discardChangesDialog(for:)`.
struct GuardedSelection<Item: Hashable> {
    /// What the detail column shows. Bind `.splitDetail` to this.
    var selection: Item?
    /// Whether the editor for `selection` has unsaved changes.
    var isDirty = false
    /// A requested selection waiting on the discard confirmation.
    private(set) var pending: Item??

    init(selection: Item? = nil) {
        self.selection = selection
    }

    var isConfirmingDiscard: Bool { pending != nil }

    /// Switches to `item`, or asks first when that would drop unsaved edits.
    mutating func request(_ item: Item?) {
        guard item != selection else { return }
        if isDirty {
            pending = .some(item)
        } else {
            selection = item
        }
    }

    /// The user chose "Discard Changes": go where they asked.
    mutating func discardAndContinue() {
        guard let target = pending else { return }
        pending = nil
        isDirty = false
        selection = target
    }

    /// The user chose "Keep Editing": stay put.
    mutating func keepEditing() {
        pending = nil
    }

    /// The editor closed itself (saved, or cancelled with nothing to lose).
    mutating func close() {
        pending = nil
        isDirty = false
        selection = nil
    }
}

extension View {
    /// The "Discard changes?" confirmation for a `GuardedSelection` — the same
    /// wording as the editors' own Cancel confirmation.
    func discardChangesDialog<Item: Hashable>(for guarded: Binding<GuardedSelection<Item>>) -> some View {
        confirmationDialog(
            "Discard changes?",
            isPresented: Binding(
                get: { guarded.wrappedValue.isConfirmingDiscard },
                set: { if !$0 { guarded.wrappedValue.keepEditing() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) { guarded.wrappedValue.discardAndContinue() }
            Button("Keep Editing", role: .cancel) { guarded.wrappedValue.keepEditing() }
        }
    }
}
