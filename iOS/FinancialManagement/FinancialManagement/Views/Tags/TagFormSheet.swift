import SwiftUI

struct TagFormSheet: View {
    enum Mode: Identifiable {
        case add
        case edit(Tag)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let tag): return "edit-\(tag.id)"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let onSaved: (() async -> Void)?

    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var showDiscardConfirm = false

    private let repository = TagRepository()

    init(mode: Mode, onSaved: (() async -> Void)? = nil) {
        self.mode = mode
        self.onSaved = onSaved
    }

    private var isEditing: Bool {
        if case .edit = mode { true } else { false }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    private var hasChanges: Bool {
        switch mode {
        case .add:
            return !name.isEmpty
        case .edit(let tag):
            return name != tag.name
        }
    }

    private var title: String {
        isEditing ? "Edit tag" : "New tag"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            cardField(title: "Name") {
                                TextField("Name", text: $name)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .frame(height: 44)
                                    .background(Color.appBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                            .strokeBorder(Color.appInput, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            }

                            if let error = errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(Color.appDanger)
                            }
                        }
                        .padding(20)
                        .appCardSurface()
                    }
                    .padding(16)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { showDiscardConfirm = true }
                        else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task { await save() }
                    }
                    .disabled(trimmedName.isEmpty || isSaving)
                }
            }
            .onAppear(perform: loadInitialValues)
            .interactiveDismissDisabled(hasChanges || isSaving)
            .confirmationDialog(
                "Discard changes?",
                isPresented: $showDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
        }
    }

    private func cardField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.appForeground)
            content()
        }
    }

    private func loadInitialValues() {
        guard !didLoad else { return }
        didLoad = true
        if case .edit(let tag) = mode {
            name = tag.name
        }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil

        do {
            switch mode {
            case .add:
                _ = try await repository.create(name: trimmed, userId: try currentUserId())
            case .edit(let tag):
                _ = try await repository.update(id: tag.id, name: trimmed)
            }
            await onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func currentUserId() throws -> UUID {
        if let id = SupabaseService.shared.client.auth.session.user.id as UUID? {
            return id
        }
        throw NSError(domain: "Auth", code: 401)
    }
}
