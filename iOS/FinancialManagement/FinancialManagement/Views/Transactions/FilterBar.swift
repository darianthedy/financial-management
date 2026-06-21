import SwiftUI

struct FilterBar: View {
    @Binding var selectedType: TransactionType?
    var onChanged: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: selectedType == nil
                ) {
                    selectedType = nil
                    onChanged()
                }

                ForEach(TransactionType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.rawValue.capitalized,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                        onChanged()
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.appPrimary : Color.appMuted, in: Capsule())
                .foregroundStyle(isSelected ? Color.appPrimaryForeground : Color.appForeground)
        }
    }
}
