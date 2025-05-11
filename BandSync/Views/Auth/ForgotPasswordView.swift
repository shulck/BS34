//
//  ForgotPasswordView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var emailSent = false

    var body: some View {
        ZStack {
            Image("bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    Text("Reset Your Password")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if emailSent {
                        Image(systemName: "envelope.open.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.green)

                        Text("Reset Email Sent")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)

                        Text("You can now reset your password using the email sent to:")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.8))

                        Text(viewModel.email)
                            .font(.body)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)

                        Text("After resetting your password, log in again using your new credentials.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .foregroundColor(.white.opacity(0.8))

                    } else {
                        Text("Enter your email to receive password reset instructions.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.8))

                        TextField("Email", text: $viewModel.email)
                            .onChange(of: viewModel.email) { _ in viewModel.errorMessage = nil }
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .environment(\.colorScheme, .dark)
                            .textContentType(.emailAddress)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .accentColor(.white)

                        Button(action: {
                            if validateEmail() {
                                viewModel.resetPassword()
                                emailSent = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "key.fill")
                                Text("Reset Password")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                        }
                        .opacity(isResetButtonEnabled ? 1.0 : 0.6)
                        .disabled(!isResetButtonEnabled)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: {
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Back to Login")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .padding(.top, 10)
                }
                .padding(20)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)
                .frame(maxWidth: 360)
                .shadow(radius: 12)

                Spacer()
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
    }

    private var isResetButtonEnabled: Bool {
        !viewModel.email.isEmpty && isValidEmail(viewModel.email)
    }

    private func validateEmail() -> Bool {
        if viewModel.email.isEmpty {
            viewModel.errorMessage = "Email cannot be empty."
            return false
        }
        if !isValidEmail(viewModel.email) {
            viewModel.errorMessage = "Invalid email format."
            return false
        }
        viewModel.errorMessage = nil
        return true
    }

    private func isValidEmail(_ email: String) -> Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }
}
