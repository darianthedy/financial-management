import SwiftUI
import UIKit

struct CategoryFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// nil = create; non-nil = edit.
    let category: Category?
    var onSaved: (() async -> Void)?

    // Same palette as web's CATEGORY_COLORS and CategoryPicker.swift.
    static let palette: [String] = [
        "#6366f1", "#f59e0b", "#10b981", "#ef4444",
        "#3b82f6", "#8b5cf6", "#ec4899", "#14b8a6",
    ]

    @State private var name = ""
    @State private var selectedColor: String = "#6366f1"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var showDiscardConfirm = false
    /// The swatch grid's width, for `SwatchGridLayout`; 0 until measured.
    @State private var swatchGridWidth: CGFloat = 0

    private let repository = CategoryRepository()

    init(category: Category? = nil, onSaved: (() async -> Void)? = nil) {
        self.category = category
        self.onSaved = onSaved
    }

    private var isEditing: Bool { category != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        if let category {
            return name != category.name
                || selectedColor != (category.color ?? Self.palette[0])
        }
        return !name.isEmpty || selectedColor != Self.palette[0]
    }

    private var isPaletteColor: Bool { Self.palette.contains(selectedColor) }

    /// Binding that converts SwiftUI Color ↔ the hex `selectedColor` string.
    private var colorPickerBinding: Binding<Color> {
        Binding(
            get: { Color(hex: selectedColor) ?? Color.appPrimary },
            set: { newColor in selectedColor = Self.hexString(for: newColor) }
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }

                Section("Color") {
                    colorPaletteGrid
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    LabeledContent("Custom color") { customColorButton }
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(Color.appDanger)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit category" : "New category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { showDiscardConfirm = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task { await save() }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .onAppear(perform: loadInitialValues)
            .interactiveDismissDisabled(hasChanges || isSaving)
            .confirmationDialog(
                "Discard changes?",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
        }
    }

    // MARK: - Color palette

    /// The palette swatches, in an even column count (`SwatchGridLayout`).
    /// Each fills an equal share of its row; min height 44 pt (HIG tap target).
    private var colorPaletteGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 0),
            count: SwatchGridLayout.columns(width: swatchGridWidth)
        )
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Self.palette, id: \.self) { hex in
                paletteCircle(hex: hex)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { swatchGridWidth = $0 }
    }

    private func paletteCircle(hex: String) -> some View {
        let isSelected = selectedColor == hex
        return Button {
            selectedColor = hex
        } label: {
            Circle()
                .fill(Color(hex: hex) ?? Color.appMutedForeground)
                .frame(width: 24, height: 24)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.appForeground, lineWidth: 2)
                            .padding(-3)
                    }
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    /// The custom-color button wraps SwiftUI's `ColorPicker` swatch with a visual
    /// overlay:
    ///   • `+` when a palette color is active (hints that clicking picks a custom hue).
    ///   • ring when a custom color is active (matches the selected-state ring on palette circles).
    /// The overlay is non-interactive so touches fall through to the underlying ColorPicker.
    private var customColorButton: some View {
        let isCustom = !isPaletteColor
        return ZStack {
            ColorPicker("Custom color", selection: colorPickerBinding, supportsOpacity: false)
                .labelsHidden()

            if isCustom {
                // Ring around the swatch that the ColorPicker renders.
                Circle()
                    .strokeBorder(Color.appForeground, lineWidth: 2)
                    .frame(width: 32, height: 32)
                    .allowsHitTesting(false)
            } else {
                // "+" hint on top of the swatch (which shows the active palette color).
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.appForeground.opacity(0.6))
                    .allowsHitTesting(false)
            }
        }
        .frame(minWidth: 44, minHeight: 44)
    }

    // MARK: - Helpers

    private static func hexString(for color: Color) -> String {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x",
                      Int(round(r * 255)),
                      Int(round(g * 255)),
                      Int(round(b * 255)))
    }

    private func loadInitialValues() {
        guard !didLoad else { return }
        didLoad = true
        if let category {
            name = category.name
            selectedColor = category.color ?? Self.palette[0]
        }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            if let category {
                try await repository.update(id: category.id, name: trimmed, color: selectedColor)
            } else {
                _ = try await repository.create(name: trimmed, color: selectedColor)
            }
            await onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// The category swatch grid's column count: even around the hinge (HIG), 6 in
/// an iPhone-width sheet and 8 in a form-sized one. Pure, so it's unit-tested
/// directly.
enum SwatchGridLayout {
    /// Wider than any iPhone portrait sheet's row, narrower than a form card's.
    static let minimumEightColumnWidth: CGFloat = 420

    static func columns(width: CGFloat) -> Int {
        width >= minimumEightColumnWidth ? 8 : 6
    }
}
