import SwiftUI

/// One selectable option in a `MultiSelectFacet`.
struct FacetOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    /// Optional leading glyph (emoji/icon text, e.g. a category icon).
    var leading: String? = nil

    var id: Value { value }
}

/// Reusable tri-state multi-select section bound to an optional `Facet`.
///
/// Renders as its own `Section` (drop it into a `Form`):
///   * a leading **"(Blanks)"** row when `allowsBlanks` is true,
///   * one checkmark row per option,
///   * a trailing **Clear** control in the header that returns the facet to its
///     *absent* state (`nil`).
///
/// Tri-state mapping (see `Facet`): no facet → absent; toggling an option
/// materialises the facet; unchecking everything (without Clear) leaves a
/// present-but-empty facet that matches nothing.
struct MultiSelectFacet<Value: Hashable & Codable>: View {
    let title: String
    let options: [FacetOption<Value>]
    var allowsBlanks: Bool = false
    @Binding var facet: Facet<Value>?

    var body: some View {
        Section {
            if allowsBlanks {
                row(label: "(Blanks)", leading: nil, isSelected: facet?.includeBlanks == true) {
                    toggleBlanks()
                }
            }
            ForEach(options) { option in
                row(
                    label: option.label,
                    leading: option.leading,
                    isSelected: facet?.values.contains(option.value) == true
                ) {
                    toggle(option.value)
                }
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                if facet != nil {
                    Button("Clear") { facet = nil }
                        .font(.caption)
                        .textCase(nil)
                }
            }
        }
    }

    private func row(label: String, leading: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                if let leading { Text(leading) }
                Text(label)
                    .foregroundStyle(Color.appForeground)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(Color.appPrimary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ value: Value) {
        var f = facet ?? Facet<Value>()
        if f.values.contains(value) {
            f.values.remove(value)
        } else {
            f.values.insert(value)
        }
        facet = f
    }

    private func toggleBlanks() {
        var f = facet ?? Facet<Value>()
        f.includeBlanks.toggle()
        facet = f
    }
}
