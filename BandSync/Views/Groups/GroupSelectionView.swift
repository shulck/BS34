//
//  GroupSelectionView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct GroupSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var showCreateGroup = false
    @State private var showJoinGroup = false
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
        
            Image("bandlogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .padding(.bottom, 10)
            
            VStack(spacing: 8) {
                Text("Welcome to BandSync!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("To get started, create a new group or join an existing one.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 16) {
                CardButton(icon: "plus.circle", text: "Create New Group", action: {
                    showCreateGroup = true
                })
                CardButton(icon: "person.badge.plus", text: "Join a Group", action: {
                    showJoinGroup = true
                })
            }
            .padding(.top, 20)
            .padding(.horizontal, 32)

            Spacer()
                     Button(action: {
                appState.logout()
            }) {
                Text("Log Out")
                    .font(.footnote)
                    .foregroundColor(.red)
            }
            .padding(.bottom, 20)
        }
        .navigationBarBackButtonHidden(true)
        .padding()
        .background(Color(UIColor.systemBackground))
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupView()
        }
        .sheet(isPresented: $showJoinGroup) {
            JoinGroupView()
        }
    }
}

// Reusable card button view
struct CardButton: View {
    let icon: String
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                Text(text)
                    .font(.body)
                    .fontWeight(.medium)
            }
            .foregroundColor(.primary)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
            )
        }
    }
}
