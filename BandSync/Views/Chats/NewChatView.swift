//
//  NewChatView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//



import SwiftUI

struct NewChatView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var isGroup = true

    var body: some View {
        NavigationView {
            Form {
                TextField("Chat name", text: $name)
                Toggle("Group chat", isOn: $isGroup)
            }
            .navigationTitle("New chat")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
//                        createChat()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }


}
