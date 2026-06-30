import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

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
        }
    }
}
