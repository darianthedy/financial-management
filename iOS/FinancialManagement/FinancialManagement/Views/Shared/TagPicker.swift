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

    /// Tags actually attached to the transaction, shown as removable chips —
    /// mirrors web's `selectedTags`.
    private var selectedTagList: [Tag] {
        tags.filter { selectedTags.contains($0.id) }
    }

    /// Available tags (not yet selected) narrowed by what the user typed —
    /// mirrors web's `filteredTags`, which drops already-selected tags from the
    /// list so they only ever appear as chips.
    private var filteredTags: [Tag] {
        tags.filter { tag in
            !selectedTags.contains(tag.id)
                && (normalizedQuery.isEmpty || tag.name.lowercased().contains(normalizedQuery))
        }
    }

    /// Offer "create" only when the typed name doesn't already exist verbatim,
    /// matching web's canCreateTag.
    private var canCreateTag: Bool {
        !normalizedQuery.isEmpty
            && !tags.contains { $0.name.lowercased() == normalizedQuery }
    }

    var body: some View {
        Section("Tags") {
            // Selected tags render as removable chips above the input, mirroring
            // web: each attached tag is a primary pill (tag glyph + name + ✕)
            // that detaches when tapped.
            if !selectedTagList.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selectedTagList) { tag in
                        Button {
                            selectedTags.remove(tag.id)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "tag")
                                Text(tag.name)
                                    .fontWeight(.medium)
                                Image(systemName: "xmark")
                            }
                            .font(.caption)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(Color.appPrimary)
                            .foregroundStyle(Color.appPrimaryForeground)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove tag \(tag.name)")
                    }
                }
            }

            // Type to filter the list and, when nothing matches, create the tag —
            // mirroring web's typeable tag input.
            TextField("Add tag", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit { Task { await submitQuery() } }

            if isLoading {
                ProgressView()
            } else {
                // Only unselected, matching tags are listed; tapping one attaches
                // it (and clears the query) just like web's addTag.
                ForEach(filteredTags) { tag in
                    HStack {
                        // Web prefixes each tag with a muted tag glyph
                        // (`pages/tags.tsx`).
                        Image(systemName: "tag")
                            .font(.caption)
                            .foregroundStyle(Color.appMutedForeground)
                        Text(tag.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { addTag(tag.id) }
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
                } else if filteredTags.isEmpty {
                    // Web distinguishes "no tags exist" from "every tag is already
                    // attached".
                    Text(tags.isEmpty ? "No tags yet" : "All tags selected")
                        .foregroundStyle(Color.appMutedForeground)
                }
            }
        }
        .task {
            await loadTags()
        }
    }

    /// Attach a tag and clear the query, mirroring web's addTag.
    private func addTag(_ id: UUID) {
        selectedTags.insert(id)
        query = ""
    }

    /// Enter/return: select the first match if any, otherwise create the tag —
    /// matching web's onKeyDown handler.
    private func submitQuery() async {
        if let first = filteredTags.first {
            addTag(first.id)
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
