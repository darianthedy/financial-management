import SwiftUI

/// A titled dashboard widget, mirroring web's `Card` + `CardHeader`/`CardTitle`
/// + `CardContent` (`web/src/components/ui/card.tsx`): a `text-base font-semibold`
/// title at the top, 20pt to the content, all on the tokenized card surface with
/// `p-5` (20pt) padding. Used by the Accounts, Planned, and Unplanned widgets so
/// they share web's exact card chrome.
struct DashboardCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.appCardForeground)
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
    }
}

/// In-card empty placeholder mirroring web's shared `EmptyState`
/// (`web/src/components/ui/misc.tsx`): a dashed-border box with a centered
/// `font-medium` title and a muted `text-sm` description.
struct DashboardCardEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appForeground)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.appMutedForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .strokeBorder(
                    Color.appBorder,
                    style: StrokeStyle(lineWidth: 1, dash: [4])
                )
        )
    }
}
