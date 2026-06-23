import SwiftUI
import Supabase

struct TagPicker: View {
    @Binding var selectedTags: Set<UUID>

    @State private var tags: [Tag] = []
    @State private var isLoading = false
    @State private var query = ""
    @State private var isCreating = false

    /// Trimmed, lowercased query used for filtering and the create check.
    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Tags matching what the user typed (all tags when the field is empty).
    private var filteredTags: [Tag] {
        guard !normalizedQuery.isEmpty else { return tags }
        return tags.filter { $0.name.lowercased().contains(normalizedQuery) }
    }

    /// Offer "create" only when the typed name doesn't already exist verbatim,
    /// matching web's canCreateTag.
    private var canCreateTag: Bool {
        !normalizedQuery.isEmpty
            && !tags.contains { $0.name.lowercased() == normalizedQuery }
    }

    var body: some View {
        Section("Tags") {
            // Type to filter the list and, when nothing matches, create the tag —
            // mirroring web's typeable tag input.
            TextField("Add tag", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit { Task { await submitQuery() } }

            if isLoading {
                ProgressView()
            } else if filteredTags.isEmpty && !canCreateTag {
                Text("No tags yet")
                    .foregroundStyle(Color.appMutedForeground)
            } else {
                ForEach(filteredTags) { tag in
                    HStack {
                        // Web prefixes each tag with a muted tag glyph
                        // (`pages/tags.tsx`).
                        Image(systemName: "tag")
                            .font(.caption)
                            .foregroundStyle(Color.appMutedForeground)
                        Text(tag.name)
                        Spacer()
                        if selectedTags.contains(tag.id) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.appPrimary)
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

                if canCreateTag {
                    Button {
                        Task { await createAndSelect() }
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text("Create “\(query.trimmingCharacters(in: .whitespaces))”")
                        }
                    }
                    .disabled(isCreating)
                }
            }
        }
        .task {
            await loadTags()
        }
    }

    /// Enter/return: select the first match if any, otherwise create the tag —
    /// matching web's onKeyDown handler.
    private func submitQuery() async {
        if let first = filteredTags.first(where: { !selectedTags.contains($0.id) }) {
            selectedTags.insert(first.id)
            query = ""
        } else if canCreateTag {
            await createAndSelect()
        }
    }

    private func createAndSelect() async {
        let name = query.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !isCreating else { return }
        isCreating = true
        defer { isCreating = false }

        struct Insert: Encodable {
            let user_id: UUID
            let name: String
        }

        do {
            let client = SupabaseService.shared.client
            let userId = try await client.auth.session.user.id
            let created: Tag = try await client
                .from("tags")
                .insert(Insert(user_id: userId, name: name))
                .select()
                .single()
                .execute()
                .value
            tags.append(created)
            tags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            selectedTags.insert(created.id)
            query = ""
        } catch {
            // Tag may already exist (UNIQUE user_id, name); ignore like web.
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
