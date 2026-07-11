import SwiftUI

/// Fixed-width leading status dot shared by every row of the transaction filter
/// sheet. Reserving the same gutter on all rows — facet rows, the date Range row,
/// and the plain From/To / Min/Max rows — keeps their labels aligned in one
/// column whether or not a given row shows an active dot.
struct FilterRowDot: View {
    var isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? Color.appPrimary : .clear)
            .frame(width: 7, height: 7)
    }
}

/// One selectable option in a `MultiSelectFacet`.
struct FacetOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    /// Optional leading glyph (emoji/icon text, e.g. a category icon).
    var leading: String? = nil

    var id: Value { value }
}

/// Reusable tri-state multi-select facet, presented like web's compact filter
/// dropdown (`web/src/components/ui/multi-select.tsx`): a collapsed row that
/// shows the facet's title and a one-line summary ("All", "None", a single
/// label, or "N selected"), expanding to a checklist with "Select all" /
/// "Clear all" controls.
///
/// Selection follows web's subtractive model: the default (no facet) is **every
/// option checked** — the inactive "All" state, held as an absent facet. The
/// user unchecks values to narrow; unchecking everything is the present-but-empty
/// "None" state that matches no rows. When `allowsBlanks` is set a leading
/// "(Blanks)" option (the category / tag / budget / fixed facets) participates
/// just like any other option.
///
/// Tri-state mapping (see `Facet`): absent → "All"; present with a subset →
/// match those; present & empty → match nothing.
struct MultiSelectFacet<Value: Hashable & Codable>: View {
    let title: String
    let options: [FacetOption<Value>]
    var allowsBlanks: Bool = false
    @Binding var facet: Facet<Value>?

    var body: some View {
        Section {
            DisclosureGroup {
                // Web's "Select all | Clear all" toolbar.
                HStack {
                    Button("Select all") { facet = nil }
                        .disabled(facet == nil)
                    Spacer()
                    Button("Clear all") { facet = Facet() }
                        .disabled(isNone)
                }
                .font(.caption.weight(.medium))
                .buttonStyle(.borderless)

                if allowsBlanks {
                    checkRow(label: "(Blanks)", leading: nil, isChecked: isBlanksChecked) {
                        toggleBlanks()
                    }
                }
                ForEach(options) { option in
                    checkRow(label: option.label, leading: option.leading,
                             isChecked: isChecked(option.value)) {
                        toggle(option.value)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    // Leading dot marks facets that are actually constraining the
                    // query, so the active ones stand out from the "All" rows.
                    FilterRowDot(isActive: isActive)
                    Text(title)
                    Spacer()
                    Text(summary)
                        .foregroundStyle(isActive ? Color.appPrimary : Color.appMutedForeground)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Derived state

    /// The facet is constraining the query (i.e. not the absent "All" state) —
    /// drives the collapsed row's active indicator.
    private var isActive: Bool { facet != nil }

    /// Present but empty (and no blanks) — the "None" state that matches no rows.
    private var isNone: Bool {
        guard let f = facet else { return false }
        return f.values.isEmpty && !f.includeBlanks
    }

    /// Absent facet = everything checked, so a value is checked unless explicitly
    /// dropped from a materialised subset.
    private func isChecked(_ value: Value) -> Bool {
        guard let f = facet else { return true }
        return f.values.contains(value)
    }

    private var isBlanksChecked: Bool {
        guard let f = facet else { return true }
        return f.includeBlanks
    }

    private var totalCount: Int { options.count + (allowsBlanks ? 1 : 0) }

    private var checkedCount: Int {
        guard let f = facet else { return totalCount }
        return f.values.count + (f.includeBlanks ? 1 : 0)
    }

    /// Collapsed summary, mirroring web: "All" (no filter), "None", a single
    /// label, or an "N selected" count.
    private var summary: String {
        guard let f = facet else { return "All" }
        let count = checkedCount
        if count == 0 { return "None" }
        if count == 1 {
            if f.includeBlanks, f.values.isEmpty { return "(Blanks)" }
            if let only = f.values.first {
                return options.first { $0.value == only }?.label ?? "1 selected"
            }
        }
        return "\(count) selected"
    }

    // MARK: - Mutations (subtractive: start from "all", uncheck to narrow)

    /// The materialised "everything checked" facet, the starting point when the
    /// user unchecks a value from the default All state.
    private func fullFacet() -> Facet<Value> {
        Facet(values: Set(options.map(\.value)), includeBlanks: allowsBlanks)
    }

    private func toggle(_ value: Value) {
        var f = facet ?? fullFacet()
        if f.values.contains(value) { f.values.remove(value) } else { f.values.insert(value) }
        normalize(f)
    }

    private func toggleBlanks() {
        var f = facet ?? fullFacet()
        f.includeBlanks.toggle()
        normalize(f)
    }

    /// Collapse a fully-checked facet back to the absent "All" state so the
    /// inactive case stays canonical (and drops off the active-filter count).
    private func normalize(_ f: Facet<Value>) {
        let everything = f.values.count == options.count && (!allowsBlanks || f.includeBlanks)
        facet = everything ? nil : f
    }

    private func checkRow(label: String, leading: String?, isChecked: Bool,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isChecked ? Color.appPrimary : Color.appMutedForeground)
                if let leading { Text(leading) }
                Text(label)
                    .foregroundStyle(Color.appForeground)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
