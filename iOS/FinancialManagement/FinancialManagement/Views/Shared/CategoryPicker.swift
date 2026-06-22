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
