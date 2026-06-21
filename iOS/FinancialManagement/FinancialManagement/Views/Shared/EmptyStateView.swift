import SwiftUI

/// Empty-state placeholder, the native iOS counterpart to web's shared
/// `EmptyState` (`web/src/components/ui/misc.tsx`). Web renders a centered
/// title, a muted description and an optional action button; this uses the
/// platform-native `ContentUnavailableView` (which matches that layout — title,
/// muted description, and an action slot) so screens can surface a primary
/// action the same way web does, e.g. an "Add …" button.
struct EmptyStateView<Actions: View>: View {
    let title: String
    let message: String
    let systemImage: String
    @ViewBuilder let actions: Actions

    init(
        title: String,
        message: String,
        systemImage: String,
        @ViewBuilder actions: () -> Actions = { EmptyView() }
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actions = actions()
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            actions
        }
    }
}
