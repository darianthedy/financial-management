import SwiftUI
import Supabase

/// Single-select category picker. A transaction references at most one category
/// directly via `transactions.category_id` — categories are not type-scoped
/// (the table has `color`, not `type`); see iOS Tech Plan §5.5.
struct CategoryPicker: View {
    @Binding var selectedId: UUID?

    @State private var categories: [Category] = []

    var body: some View {
        Picker("Category", selection: $selectedId) {
            Text("None").tag(UUID?.none)
            ForEach(categories) { category in
                HStack {
                    if let icon = category.icon {
                        Text(icon)
                    }
                    Text(category.name)
                }
                .tag(Optional(category.id))
            }
        }
        .task { await loadCategories() }
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
