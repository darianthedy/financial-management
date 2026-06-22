import SwiftUI
import Supabase
import PhotosUI
import UIKit

struct AccountFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    /// nil = create a new account; non-nil = edit an existing one.
    let account: Account?
    var onSaved: (() async -> Void)?

    @State private var name = ""
    @State private var type: AccountType = .bankAccount
    @State private var startingBalance = ""
    @State private var showOnDashboard = true
    @State private var setAsDefault = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoad = false

    // Avatar staged locally; uploaded only on submit so cancelling never orphans
    // a Storage object. `removeImage` flags clearing an existing image.
    @State private var photoItem: PhotosPickerItem?
    @State private var stagedImage: UIImage?
    @State private var removeImage = false

    private let repository = AccountRepository()
    private let imageService = AccountImageService()

    init(account: Account? = nil, onSaved: (() async -> Void)? = nil) {
        self.account = account
        self.onSaved = onSaved
    }

    private var isEditing: Bool { account != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        avatarPreview
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label(hasImage ? "Change Photo" : "Choose Photo",
                                      systemImage: "photo")
                            }
                            if hasImage {
                                Button(role: .destructive) {
                                    stagedImage = nil
                                    photoItem = nil
                                    removeImage = true
                                } label: {
                                    Label("Remove Photo", systemImage: "trash")
                                }
                            }
                        }
                    }
                } footer: {
                    // Matches web's avatar helper copy.
                    Text("PNG, JPG, or WebP. Resized to 256px.")
                }

                Section {
                    TextField("Name", text: $name)

                    Picker("Type", selection: $type) {
                        ForEach(AccountType.allCases, id: \.self) { accountType in
                            Text(accountType.displayName).tag(accountType)
                        }
                    }

                    CurrencyField(label: "Starting Balance", value: $startingBalance)
                }

                // web gives each checkbox its own helper text.
                Section {
                    Toggle("Show on dashboard", isOn: $showOnDashboard)
                } footer: {
                    Text("When off, this account and its balance are hidden from the dashboard's Accounts card.")
                }

                Section {
                    Toggle("Set as default account", isOn: $setAsDefault)
                } footer: {
                    Text("Pre-selected when you add a new transaction. Only one account can be the default.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(Color.appDanger)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Account" : "New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let decimalPlaces = appState.decimalPlaces
                        let wasDefault = account.map { appState.defaultAccountId == $0.id } ?? false
                        Task { await save(decimalPlaces: decimalPlaces, wasDefault: wasDefault) }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .onAppear(perform: loadInitialValues)
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        stagedImage = image
                        removeImage = false
                    }
                }
            }
        }
    }

    /// Shows the freshly picked image, the existing avatar, or the type fallback.
    @ViewBuilder
    private var avatarPreview: some View {
        if let stagedImage {
            Image(uiImage: stagedImage)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
        } else {
            AccountAvatar(imageUrl: removeImage ? nil : account?.imageUrl,
                          accountType: type, size: 64)
        }
    }

    private var hasImage: Bool {
        if stagedImage != nil { return true }
        if removeImage { return false }
        return account?.imageUrl != nil
    }

    private func loadInitialValues() {
        guard !didLoad else { return }
        didLoad = true
        if let account {
            name = account.name
            type = account.type
            startingBalance = Self.balanceString(account.startingBalance, decimalPlaces: appState.decimalPlaces)
            showOnDashboard = account.showOnDashboard
            setAsDefault = appState.defaultAccountId == account.id
        }
    }

    private func save(decimalPlaces: Int, wasDefault: Bool) async {
        isSaving = true
        defer { isSaving = false }

        let balance = CurrencyUtils.toMinorUnits(Double(startingBalance) ?? 0, decimalPlaces: decimalPlaces)

        do {
            // Resolve the avatar: upload a newly staged image, clear it, or keep it.
            // Upload happens here (on submit) so cancelling never orphans an object.
            let oldImageUrl = account?.imageUrl
            var imageUrlToSave: String? = oldImageUrl
            var imageChanged = false
            if let stagedImage {
                imageUrlToSave = try await imageService.upload(image: stagedImage)
                imageChanged = true
            } else if removeImage {
                imageUrlToSave = nil
                imageChanged = true
            }

            let accountId: UUID
            if let account {
                var fields: [String: AnyJSON] = [
                    "name": .string(name),
                    "type": .string(type.rawValue),
                    "starting_balance": .integer(Int(balance)),
                    "show_on_dashboard": .bool(showOnDashboard)
                ]
                if imageChanged {
                    fields["image_url"] = imageUrlToSave.map { .string($0) } ?? .null
                }
                try await repository.update(id: account.id, fields: fields)
                accountId = account.id
            } else {
                let created = try await repository.create(
                    name: name,
                    type: type,
                    startingBalance: balance,
                    imageUrl: imageUrlToSave,
                    showOnDashboard: showOnDashboard
                )
                accountId = created.id
            }

            // Default account lives on user_settings (one at a time), never on the
            // account row. Only write when the toggle actually changed.
            if setAsDefault && !wasDefault {
                try await appState.setDefaultAccount(accountId)
            } else if !setAsDefault && wasDefault {
                try await appState.setDefaultAccount(nil)
            }

            // Best-effort delete of the replaced/removed object, AFTER the row save.
            if imageChanged, let oldImageUrl, oldImageUrl != imageUrlToSave {
                await imageService.deletePreviousObject(publicURL: oldImageUrl)
            }

            await onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func balanceString(_ minorUnits: Int64, decimalPlaces: Int) -> String {
        let amount = CurrencyUtils.toDisplayAmount(minorUnits, decimalPlaces: decimalPlaces)
        return String(format: "%.\(decimalPlaces)f", amount)
    }
}
