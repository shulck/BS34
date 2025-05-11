//
//  CustomTextField.swift
//  BandSync
//
//  Created by Akash 's Mac M1 on 23/04/2025.
//

import SwiftUI

struct CustomTextField: View {
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var error: String

    init(_ placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, error: String) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.error = error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textContentType(.name)
                .autocapitalization(.none)
                .padding()
                .background(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(error.isEmpty ? Color.gray.opacity(0.3) : Color.red, lineWidth: 1)
                )
                .cornerRadius(12)
                .foregroundColor(.primary)

            if !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}
