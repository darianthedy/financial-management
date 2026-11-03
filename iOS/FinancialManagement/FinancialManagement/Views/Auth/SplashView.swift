import SwiftUI

struct SplashView: View {
    @Environment(\.foldContext) private var fold

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            // Centered, or in one region so the logo never sits on the fold.
            FoldRegions(fold: fold) {
                VStack(spacing: 16) {
                    Image(systemName: "banknote")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.appPrimary)

                    Text("Financial Management")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.appForeground)

                    ProgressView()
                        .tint(Color.appPrimary)
                        .padding(.top, 8)
                }
                .layoutProbe("splash.content")
            }
        }
    }
}
