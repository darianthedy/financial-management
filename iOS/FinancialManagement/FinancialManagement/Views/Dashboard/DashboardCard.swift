import SwiftUI

/// A titled dashboard widget, mirroring web's `Card` + `CardHeader`/`CardTitle`
/// + `CardContent` (`web/src/components/ui/card.tsx`): a `text-base font-semibold`
/// title at the top, 20pt to the content, all on the tokenized card surface with
/// `p-5` (20pt) padding. Used by the Accounts, Planned, and Unplanned widgets so
/// they share web's exact card chrome.
struct DashboardCard<Content: View, Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    init(
        title: String,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title row mirrors web's `CardHeader` flex row: the title on the
            // left with an optional trailing accessory (e.g. a status chip).
            // When both don't fit on one line (a narrow column or ⅓ Split
            // View, D4.2) the accessory wraps under the title instead of
            // squeezing either into truncation.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    titleText
                    Spacer(minLength: 8)
                    accessory
                }
                VStack(alignment: .leading, spacing: 8) {
                    titleText
                    accessory
                }
            }
            .layoutProbe("dashboardCard.header.\(title)")
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardSurface()
    }

    private var titleText: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Color.appCardForeground)
    }
}

extension DashboardCard where Accessory == EmptyView {
    /// Accessory-less card: just a title and content, as used by the Accounts,
    /// Planned, and Unplanned widgets.
    init(title: String, @ViewBuilder content: () -> Content) {
        self.init(title: title, accessory: { EmptyView() }, content: content)
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
