import SwiftUI
import Supabase

/// Single-select category picker. A transaction references at most one category
/// directly via `transactions.category_id` — categories are not type-scoped
/// (the table has `color`, not `type`); see iOS Tech Plan §5.5.
struct CategoryPicker: View {
    @Binding var selectedId: UUID?

    @State private var categories: [Category] = []
    @State private var showingCreate = false

    // Sentinel tag for the in-dropdown "Create…" item. A random UUID can't
    // collide with a real category id, so selecting it is unambiguous.
    private static let createTag = UUID()

    var body: some View {
        Picker("Category", selection: $selectedId) {
            Text("None").tag(UUID?.none)
            ForEach(categories) { category in
                HStack(spacing: 8) {
                    // Web identifies each category by a color swatch + name
                    // (`pages/categories.tsx`): a small dot in the category's
                    // own color, falling back to muted-foreground when unset.
                    Circle()
                        .fill(category.color.flatMap(Color.init(hex:)) ?? Color.appMutedForeground)
                        .frame(width: 10, height: 10)
                    Text(category.name)
                }
                .tag(Optional(category.id))
            }

            // In-dropdown create action, mirroring web's "+ Create category".
            // Selecting it opens the create sheet (handled in onChange).
            Divider()
            Label("Create category", systemImage: "plus")
                .tag(Optional(Self.createTag))
        }
        .task { await loadCategories() }
        .onChange(of: selectedId) { previousId, newId in
            // The "Create…" item isn't a real selection: revert to the prior
            // value and open the create sheet instead.
            if newId == Self.createTag {
                selectedId = previousId
                showingCreate = true
            }
        }
        .sheet(isPresented: $showingCreate) {
            CreateCategorySheet { newCategoryId in
                await loadCategories()
                selectedId = newCategoryId
            }
        }
    }

    private func loadCategories() async {
        do {
            let client = SupabaseService.shared.client
            categories = try await client
                .from("categories")
                .select()
                .order("name")
                .execute()
                .value
        } catch {
            categories = []
        }
    }
}

/// Minimal inline category creation (name only), mirroring web's CategoryForm.
/// The color is derived from the name so new categories get a stable, distinct
/// swatch, matching web's `colorForName`.
private struct CreateCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreated: (UUID) async -> Void

    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Same palette as web's CATEGORY_COLORS so iOS- and web-created categories
    // share the same color assignment.
    private static let palette = [
        "#6366f1", "#f59e0b", "#10b981", "#ef4444",
        "#3b82f6", "#8b5cf6", "#ec4899", "#14b8a6",
    ]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("New Category") {
                    TextField("Name", text: $name)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Color.appDanger) }
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(!isValid || isSaving)
                }
            }
        }
    }

    /// Stable hash → palette index, matching web's `colorForName` (32-bit
    /// unsigned `hash * 31 + charCode` over UTF-16 code units).
    private func colorForName(_ name: String) -> String {
        var hash: UInt32 = 0
        for unit in name.utf16 {
            hash = hash &* 31 &+ UInt32(unit)
        }
        return Self.palette[Int(hash % UInt32(Self.palette.count))]
    }

    private func create() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }

        struct Insert: Encodable {
            let user_id: UUID
            let name: String
            let color: String
        }
        struct Created: Decodable { let id: UUID }

        do {
            let client = SupabaseService.shared.client
            let userId = try await client.auth.session.user.id
            let created: Created = try await client
                .from("categories")
                .insert(Insert(user_id: userId, name: trimmed, color: colorForName(trimmed)))
                .select("id")
                .single()
                .execute()
                .value
            await onCreated(created.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
