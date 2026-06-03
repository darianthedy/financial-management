import SwiftUI

struct CurrencyPicker: View {
    let label: String
    @Binding var selectedCode: String
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationLink {
            CurrencyPickerList(selectedCode: $selectedCode, currencies: appState.currencies)
        } label: {
            LabeledContent(label) {
                if let currency = appState.currency(for: selectedCode) {
                    Text("\(currency.symbol) \(currency.code)")
                        .foregroundStyle(.secondary)
                } else {
                    Text(selectedCode)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct CurrencyPickerList: View {
    @Binding var selectedCode: String
    let currencies: [Currency]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [Currency] {
        if searchText.isEmpty { return currencies }
        let query = searchText.lowercased()
        return currencies.filter {
            $0.code.lowercased().contains(query) ||
            $0.name.lowercased().contains(query)
        }
    }

    var body: some View {
        List(filtered) { currency in
            Button {
                selectedCode = currency.code
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(currency.code)
                            .font(.headline)
                        Text(currency.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(currency.symbol)
                        .foregroundStyle(.secondary)

                    if currency.code == selectedCode {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .tint(.primary)
        }
        .searchable(text: $searchText, prompt: "Search currencies")
        .navigationTitle("Select Currency")
        .navigationBarTitleDisplayMode(.inline)
    }
}
