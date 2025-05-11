//
//  RoleView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  RoleView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI
import FirebaseFirestore

struct RoleView: View {
    let userId: String
    @State private var selectedRole: UserModel.UserRole = .member

    var body: some View {
        Form {
            Picker("Role", selection: $selectedRole) {
                ForEach(UserModel.UserRole.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }

            Button("Save") {
                changeRole()
            }
            .disabled(userId.isEmpty)
        }
        .navigationTitle("Change role")
    }

    private func changeRole() {
        Firestore.firestore().collection("users").document(userId).updateData([
            "role": selectedRole.rawValue
        ])
    }
}
