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
            // web fills the circle with `--color-muted`.
            Circle().fill(Color.appMuted)

            if let imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        // web uses `object-contain p-1`: fit the logo inside the
                        // circle with a little padding (never crop).
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.1)
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
            // web renders the fallback type icon in `--color-muted-foreground`.
            .foregroundStyle(Color.appMutedForeground)
    }
}
