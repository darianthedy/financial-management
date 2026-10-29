import SwiftUI

/// Tags (S9). Tapping a tag opens its transactions: pushed on compact, in the
/// detail column on regular width (implementation plan D2.3).
struct TagsListView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel = TagListViewModel()
    @State private var formMode: TagFormSheet.Mode?
    @State private var pendingDelete: Tag?
    @State private var selectedTag: Tag?

    init(selectedTag: Tag? = nil) {
        _selectedTag = State(initialValue: selectedTag)
    }

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
        .refreshable { await viewModel.load() }
        .splitDetail(
            selection: $selectedTag,
            in: viewModel.tags,
            id: { $0.id.uuidString },
            storageKey: "tags",
            placeholder: SplitPlaceholder(
                title: "Select a Tag",
                systemImage: "tag",
                description: "Its transactions appear here."
            )
        ) { tag in
            TransactionListView(initialFilters: filtersFor(tag))
        }
        .sheet(item: $formMode) { mode in
            TagFormSheet(mode: mode) { await viewModel.load() }
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
            let columns = TagGridColumns.items(width: geo.size.width, sizeClass: horizontalSizeClass)
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
            .splitCardSelected(selectedTag?.id == tag.id)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .layoutProbe("tags.card.\(tag.name)", interactive: true)
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

/// The tag grid's columns. Compact keeps the adaptive grid it always had. On
/// regular width the HIG prefers an **even** column count around the hinge,
/// so the count is derived from the width (one column per ~160 pt, rounded
/// down to even, at least 2) instead of `.adaptive`, which can land on odd.
enum TagGridColumns {
    static let spacing: CGFloat = 12

    static func count(width: CGFloat) -> Int {
        max(2, Int((width / 160).rounded(.down)) & ~1)
    }

    static func items(width: CGFloat, sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        guard sizeClass == .regular else {
            return [GridItem(.adaptive(minimum: 140), spacing: spacing, alignment: .top)]
        }
        return Array(
            repeating: GridItem(.flexible(), spacing: spacing, alignment: .top),
            count: count(width: width)
        )
    }
}
