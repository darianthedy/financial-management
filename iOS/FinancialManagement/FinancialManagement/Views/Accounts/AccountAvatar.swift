import SwiftUI

/// Renders an account's avatar from its `image_url`, falling back to the
/// type-based SF Symbol when no image is set. Shared by the account list card,
/// the detail header, the form preview, and (later) transaction rows.
/// See iOS Tech Plan §8.2 and System Design §4.10.
struct AccountAvatar: View {
    let imageUrl: String?
    let accountType: AccountType
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Color.secondary.opacity(0.12))

            if let imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty:
                        ProgressView()
                    case .failure:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallbackIcon: some View {
        Image(systemName: accountType.defaultIcon)
            .font(.system(size: size * 0.5))
            .foregroundStyle(.tint)
    }
}
