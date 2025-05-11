//
//  AuthService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AuthService {
    static let shared = AuthService()
    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    private init() {
        print("AuthService: initialized")
    }

    func registerUser(email: String, password: String, name: String, phone: String, completion: @escaping (Result<User, Error>) -> Void) {
        print("AuthService: starting user registration with email \(email)")

        FirebaseManager.shared.ensureInitialized()

        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                print("AuthService: error creating user: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let user = result?.user else {
                print("AuthService: User missing after creation")
                completion(.failure(NSError(domain: "UserMissing", code: -1, userInfo: nil)))
                return
            }

            let uid = user.uid
            print("AuthService: user created with UID: \(uid)")

            let userData: [String: Any] = [
                "id": uid,
                "email": email,
                "name": name,
                "phone": phone,
                "groupId": NSNull(),
                "role": "Member"
            ]

            print("AuthService: saving user data to Firestore")

            self?.db.collection("users").document(uid).setData(userData) { error in
                if let error = error {
                    print("AuthService: error saving user data: \(error.localizedDescription)")
                    completion(.failure(error))
                } else {
                    print("AuthService: user data successfully saved")
                    completion(.success(user))
                }
            }
        }
    }

    func loginUser(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        print("AuthService: attempting to log in user with email \(email)")

        FirebaseManager.shared.ensureInitialized()

        auth.signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("AuthService: error logging in: \(error.localizedDescription)")
                completion(.failure(error))
            } else if let user = result?.user {
                print("AuthService: user login successful")
                completion(.success(user))
            } else {
                print("AuthService: unexpected nil user after login")
                completion(.failure(NSError(domain: "UserLoginNil", code: -1, userInfo: nil)))
            }
        }
    }

    func resetPassword(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("AuthService: sending password reset request for email \(email)")

        FirebaseManager.shared.ensureInitialized()

        auth.sendPasswordReset(withEmail: email) { error in
            if let error = error {
                print("AuthService: error resetting password: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                print("AuthService: password reset request sent successfully")
                completion(.success(()))
            }
        }
    }

    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        print("AuthService: attempting to log out user")

        FirebaseManager.shared.ensureInitialized()

        do {
            try auth.signOut()
            print("AuthService: user logout successful")
            completion(.success(()))
        } catch {
            print("AuthService: error logging out: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }

    func isUserLoggedIn() -> Bool {
        FirebaseManager.shared.ensureInitialized()
        let isLoggedIn = auth.currentUser != nil
        print("AuthService: user is \(isLoggedIn ? "authorized" : "not authorized")")
        return isLoggedIn
    }

    func currentUserUID() -> String? {
        FirebaseManager.shared.ensureInitialized()
        return auth.currentUser?.uid
    }
}
