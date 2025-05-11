//
//  AuthViewModel.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import Foundation
import Combine
import FirebaseAuth
import KeychainSwift

final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var name = ""
    @Published var phone = ""
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isEmailVerificationSent = false
    func login() {
            guard !email.isEmpty, !password.isEmpty else {
                errorMessage = "Email and password cannot be empty."
                return
            }

            isLoading = true
            AuthService.shared.loginUser(email: email, password: password) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let user):
                        if user.isEmailVerified {
                            self?.isAuthenticated = true
                            AppState.shared.refreshAuthState()
                            self?.isLoading = false

                            // Save credentials for Face ID
                            let keychain = KeychainSwift()
                            keychain.set(self?.email ?? "", forKey: "savedEmail")
                            keychain.set(self?.password ?? "", forKey: "savedPassword")
                            keychain.set("true", forKey: "faceIDEnabled")
                        } else {
                            self?.errorMessage = "Please verify your email before logging in."
                            try? Auth.auth().signOut()
                        }
                    case .failure:
                        self?.errorMessage = "Invalid email or password. Please try again."
                        self?.isLoading = false
                    }
                }
            }
        }


    func register() {
        isLoading = true
        AuthService.shared.registerUser(email: email, password: password, name: name, phone: phone) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let user):
                    user.sendEmailVerification { error in
                        if let error = error {
                            self?.errorMessage = "Failed to send verification email: \(error.localizedDescription)"
                        } else {
                            self?.isEmailVerificationSent = true
                            self?.errorMessage = "Verification email sent. Please check your inbox."
                            try? Auth.auth().signOut()
                        }
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func resendVerificationEmail() {
        guard let user = Auth.auth().currentUser else {
            self.errorMessage = "User not found. Please log in again."
            return
        }

        // Only resend the email verification if the user is still not verified
        if user.isEmailVerified {
            self.errorMessage = "Your email is already verified."
            return
        }

        user.sendEmailVerification { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Could not resend email: \(error.localizedDescription)"
                } else {
                    self.errorMessage = "Verification email resent."
                }
            }
        }
    }


    func resetPassword() {
        isLoading = true
        AuthService.shared.resetPassword(email: email) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success:
                    self?.errorMessage = "Password reset email sent"
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
