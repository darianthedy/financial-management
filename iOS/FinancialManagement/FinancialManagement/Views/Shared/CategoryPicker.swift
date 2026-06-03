import SwiftUI
import Supabase

struct CategoryPicker: View {
    @Binding var selectedId: UUID?
    var transactionType: TransactionType

    @State private var categories: [Category] = []
    @State private var isLoading = false

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
        .task {
            await loadCategories()
        }
        .onChange(of: transactionType) {
            Task { await loadCategories() }
        }
    }

    private func loadCategories() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let client = SupabaseService.shared.client
            categories = try await client
                .from("categories")
                .select()
                .eq("type", value: transactionType.rawValue)
                .order("name")
                .execute()
                .value
        } catch {
            categories = []
        }
    }
}
