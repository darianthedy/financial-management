import SwiftUI

/// Categories (S10). Tapping a category opens its transactions: pushed on
/// compact, in the detail column on regular width (implementation plan D2.2).
struct CategoryListView: View {
    @State private var viewModel = CategoryListViewModel()
    @State private var showingAddSheet = false
    @State private var editingCategory: Category?
    @State private var pendingDelete: Category?
    @State private var selectedCategory: Category?

    init(selectedCategory: Category? = nil) {
        _selectedCategory = State(initialValue: selectedCategory)
    }

    var body: some View {
        List {
            ForEach(viewModel.categories) { category in
                categoryRow(category)
                    .splitRowSelected(selectedCategory?.id == category.id)
                    .layoutProbe("categories.row.\(category.name)", interactive: true)
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .overlay {
            if viewModel.categories.isEmpty && !viewModel.isLoading {
                EmptyStateView(
                    title: "No categories yet",
                    message: "Create categories to classify your income and expenses.",
                    systemImage: "tag"
                ) {
                    Button("Add category") { showingAddSheet = true }
                }
            }
        }
        .refreshable { await viewModel.load() }
        .splitDetail(
            selection: $selectedCategory,
            in: viewModel.categories,
            id: { $0.id.uuidString },
            storageKey: "categories",
            placeholder: SplitPlaceholder(
                title: "Select a Category",
                systemImage: "tag",
                description: "Its transactions appear here."
            )
        ) { category in
            DrilldownTransactionList(screen: "categories", item: category.id.uuidString, filters: filtersFor(category))
        }
        .foldSafeSheet(isPresented: $showingAddSheet) {
            CategoryFormSheet { await viewModel.load() }
        }
        .foldSafeSheet(item: $editingCategory) { category in
            CategoryFormSheet(category: category) { await viewModel.load() }
        }
        .alert(
            Text(verbatim: "Delete \"\(pendingDelete?.name ?? "category")\"?"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { category in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(category) }
            }
        } message: { _ in
            Text("Transactions using it will become uncategorized.")
        }
        .task {
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 0) {
            // Left tap zone — navigates to the transactions filtered by this category.
            Button {
                selectedCategory = category
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(category.color.flatMap(Color.init(hex:)) ?? Color.appMutedForeground)
                        .frame(width: 10, height: 10)
                    Text(category.name)
                        .foregroundStyle(Color.appForeground)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ⋮ menu — edit or delete without navigating.
            Menu {
                Button { editingCategory = category } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    pendingDelete = category
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color.appMutedForeground)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        // Swipe mirrors the ⋮ menu; allowsFullSwipe:false so Delete requires
        // confirming via the alert rather than auto-firing on a long swipe.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDelete = category
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { editingCategory = category } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Color.appPrimary)
        }
    }

    // MARK: - Helpers

    private func filtersFor(_ category: Category) -> TransactionFilters {
        var f = TransactionFilters()
        f.categories = Facet(values: [category.id])
        return f
    }
}
