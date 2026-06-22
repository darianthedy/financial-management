import SwiftUI

/// Auth entry screen. Mirrors web's login page (`web/src/pages/login.tsx`): a
/// single centered card on the app background with the product title, a muted
/// subtitle, labeled Email/Password fields, an inline field error in the danger
/// token, and a full-width primary button.
///
/// Web has no self-serve sign-up, but the iOS build keeps account creation as an
/// intentional native affordance (the toggle below). In sign-in mode the copy
/// matches web exactly ("Sign in to your account", "Sign in" / "Signing in…").
struct LoginView: View {
    @State private var viewModel = AuthViewModel()
    @State private var isSignUp = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(alignment: .leading, spacing: 16) {
                        field(title: "Email") {
                            TextField("you@example.com", text: $viewModel.email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        field(title: "Password") {
                            SecureField("••••••••", text: $viewModel.password)
                                .textContentType(isSignUp ? .newPassword : .password)
                        }

                        if let error = viewModel.errorMessage {
                            // web FieldError: text-xs text-[--color-danger]
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.appDanger)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        submitButton

                        Button(isSignUp
                               ? "Already have an account? Sign in"
                               : "Don't have an account? Sign up") {
                            isSignUp.toggle()
                            viewModel.errorMessage = nil
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.appPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .appCardSurface()
                }
                .frame(maxWidth: 400)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "banknote")
                .font(.system(size: 44))
                .foregroundStyle(Color.appPrimary)
            // web CardTitle: text-xl font-semibold
            Text("Financial Management")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.appForeground)
            // web subtitle: text-sm text-[--color-muted-foreground]
            Text(isSignUp ? "Create your account" : "Sign in to your account")
                .font(.subheadline)
                .foregroundStyle(Color.appMutedForeground)
        }
    }

    private var submitButton: some View {
        Button {
            Task {
                if isSignUp {
                    await viewModel.signUp()
                } else {
                    await viewModel.signIn()
                }
            }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(Color.appPrimaryForeground)
                } else {
                    Text(isSignUp ? "Create account" : "Sign in")
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.appPrimary)
            .foregroundStyle(Color.appPrimaryForeground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .opacity(viewModel.isLoading ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
    }

    /// A labeled form field matching web's `Label` + `Input`: a medium-weight
    /// label above a control with an input-token border, background fill and
    /// `--radius` corners.
    private func field<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.appForeground)
            content()
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Color.appBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .strokeBorder(Color.appInput, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        }
    }
}
