import SwiftUI

struct TagsListView: View {
    @State private var viewModel = TagListViewModel()
    @State private var formMode: TagFormSheet.Mode?
    @State private var pendingDelete: Tag?
    @State private var selectedTag: Tag?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.tags.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.tags.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                tagGrid
            }
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    formMode = .add
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $formMode) { mode in
            TagFormSheet(mode: mode) { await viewModel.load() }
        }
        .navigationDestination(item: $selectedTag) { tag in
            TransactionListView(
                initialFilters: filtersFor(tag)
            )
        }
        .alert(
            Text(verbatim: "Delete \"\(pendingDelete?.name ?? "tag")\"?"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { tag in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(tag) }
            }
        } message: { tag in
            Text("Delete \"\(tag.name)\"? It will be removed from any transactions using it.")
        }
        .task {
            await viewModel.load()
            await viewModel.subscribeToChanges()
        }
        .onDisappear {
            Task { await viewModel.unsubscribe() }
        }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Empty

    private var emptyState: some View {
        EmptyStateView(
            title: "No tags yet",
            message: "Create tags to label transactions across categories.",
            systemImage: "tag"
        ) {
            Button("Add tag") {
                formMode = .add
            }
        }
    }

    // MARK: - Grid

    private var tagGrid: some View {
        GeometryReader { geo in
            let columns = [
                GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)
            ]
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.tags) { tag in
                        tagCard(tag: tag)
                    }
                }
                .padding(16)
                .frame(
                    minHeight: geo.size.height,
                    maxHeight: .infinity,
                    alignment: .top
                )
            }
            .background(Color.appBackground)
        }
    }

    private func tagCard(tag: Tag) -> some View {
        Button {
            selectedTag = tag
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "tag.fill")
                    .foregroundStyle(Color.appPrimary)
                    .imageScale(.medium)
                Text(tag.name)
                    .font(.headline)
                    .foregroundStyle(Color.appForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(14)
            .appCardSurface()
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit") {
                formMode = .edit(tag)
            }
        }
    }

    // MARK: - Filter helper

    private func filtersFor(_ tag: Tag) -> TransactionFilters {
        var f = TransactionFilters()
        f.tags = Facet(values: [tag.id])
        return f
    }
}
