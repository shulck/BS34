//
//  ContentView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//  Updated by Claude AI on 31.03.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @State private var shouldCheckAuth = false

    var body: some View {
        Group {
            if !shouldCheckAuth {
                // Display a simple loading screen or splash view
                VStack {
                    Text("Loading...")
                    ProgressView()
                }
                .onAppear {
                    // Delay the evaluation by 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        shouldCheckAuth = true
                    }
                }
            } else {
                // Evaluate the conditions after the delay
                if !appState.isLoggedIn {
                    LoginView()
                } else if appState.user?.groupId != nil {
                    MainTabView()
                } else {
                    GroupSelectionView()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
