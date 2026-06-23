import SwiftUI
import Supabase

struct TagPicker: View {
    @Binding var selectedTags: Set<UUID>

    @State private var tags: [Tag] = []
    @State private var isLoading = false
    @State private var showingPicker = false

    /// Attached tags, in the same name order as the loaded list — shown as chips
    /// on the form row, mirroring web's selected-tag chips.
    private var selectedTagList: [Tag] {
        tags.filter { selectedTags.contains($0.id) }
    }

    var body: some View {
        Section("Tags") {
            // Tapping the row opens a searchable picker sheet (web opens a tag
            // dropdown). The row itself summarizes the current selection as chips.
            Button {
                showingPicker = true
            } label: {
                HStack {
                    Group {
                        if selectedTagList.isEmpty {
                            Text("Add tags")
                                .foregroundStyle(Color.appMutedForeground)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(selectedTagList) { tag in
                                    TagChip(name: tag.name)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.appMutedForeground)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .task { await loadTags() }
        .sheet(isPresented: $showingPicker) {
            TagPickerSheet(tags: $tags, selectedTags: $selectedTags, isLoading: isLoading)
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

/// A primary-tinted pill (tag glyph + name) used to display attached tags,
/// mirroring web's selected-tag chips.
private struct TagChip: View {
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag")
            Text(name)
                .fontWeight(.medium)
        }
        .font(.caption)
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(Color.appPrimary)
        .foregroundStyle(Color.appPrimaryForeground)
        .clipShape(Capsule())
    }
}

/// Searchable multi-select sheet: filter the tag list, toggle tags on/off, and —
/// when the query matches nothing — create the tag inline. Mirrors web's
/// typeable tag dropdown (filter + create), adapted to a native iOS sheet.
private struct TagPickerSheet: View {
    @Binding var tags: [Tag]
    @Binding var selectedTags: Set<UUID>
    let isLoading: Bool

    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            List {
                if isLoading && tags.isEmpty {
                    ProgressView()
                } else {
                    ForEach(filteredTags) { tag in
                        Button {
                            toggle(tag.id)
                        } label: {
                            HStack {
                                // Web prefixes each tag with a muted tag glyph.
                                Image(systemName: "tag")
                                    .font(.caption)
                                    .foregroundStyle(Color.appMutedForeground)
                                Text(tag.name)
                                    .foregroundStyle(Color.appForeground)
                                Spacer()
                                if selectedTags.contains(tag.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appPrimary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                        // Distinguish "no tags exist yet" from "nothing matches the
                        // current search".
                        Text(tags.isEmpty ? "No tags yet" : "No matching tags")
                            .foregroundStyle(Color.appMutedForeground)
                    }
                }
            }
            .searchable(text: $query, prompt: "Search or add a tag")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            // Enter/return: select the first match, otherwise create the tag —
            // matching web's onKeyDown handler.
            .onSubmit(of: .search) { Task { await submitQuery() } }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedTags.contains(id) {
            selectedTags.remove(id)
        } else {
            selectedTags.insert(id)
        }
    }

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
}
