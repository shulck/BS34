//
//  PhoneVerificationView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI
import FirebaseAuth

struct PhoneVerificationView: View {
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var verificationID: String?
    @State private var isVerified = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Image("bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Phone Verification")
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .padding(.top)

                TextField("Phone number", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white, lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .accentColor(.white)

                Button(action: sendCode) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Send Code")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                }

                if verificationID != nil {
                    TextField("SMS code", text: $verificationCode)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white, lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .foregroundColor(.white)
                        .accentColor(.white)

                    Button(action: verifyCode) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Verify")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }

                if isVerified {
                    Text("Phone verified ✅")
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                        .padding(.top, 8)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: 360)
            .background(Color.black.opacity(0.5))
            .cornerRadius(20)
            .shadow(radius: 12)
            .padding()
        }
        .navigationBarBackButtonHidden(true)
    }

    private func sendCode() {
        PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { id, error in
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            verificationID = id
            errorMessage = nil
        }
    }

    private func verifyCode() {
        guard let id = verificationID else { return }
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: id, verificationCode: verificationCode)

        Auth.auth().signIn(with: credential) { result, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                isVerified = true
                errorMessage = nil
            }
        }
    }
}
