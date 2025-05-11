//
//  CustomSecureField.swift
//  BandSync
//
//  Created by Akash 's Mac M1 on 23/04/2025.
//

import SwiftUI

struct CustomSecureField: View {
    var placeholder: String
    @Binding var text: String
    var error: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SecureField(placeholder, text: $text)
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
