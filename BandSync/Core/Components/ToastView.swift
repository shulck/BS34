//
//  ToastView.swift
//  BandSync
//
//  Created by Akash 's Mac M1 on 22/04/2025.
//

import SwiftUI

struct ToastView: View {
    var message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(10)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }
}



