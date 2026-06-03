import SwiftUI
import Supabase

struct TagPicker: View {
    @Binding var selectedTags: Set<UUID>

    @State private var tags: [Tag] = []
    @State private var isLoading = false

    var body: some View {
        Section("Tags") {
            if isLoading {
                ProgressView()
            } else if tags.isEmpty {
                Text("No tags available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tags) { tag in
                    HStack {
                        Text(tag.name)
                        Spacer()
                        if selectedTags.contains(tag.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedTags.contains(tag.id) {
                            selectedTags.remove(tag.id)
                        } else {
                            selectedTags.insert(tag.id)
                        }
                    }
                }
            }
        }
        .task {
            await loadTags()
        }
    }

    private func loadTags() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let client = SupabaseService.shared.client
            tags = try await client
                .from("tags")
                .select()
                .order("name")
                .execute()
                .value
        } catch {
            tags = []
        }
    }
}
