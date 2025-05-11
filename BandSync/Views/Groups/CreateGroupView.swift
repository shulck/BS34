//
//  CreateGroupView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  CreateGroupView.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import SwiftUI

struct CreateGroupView: View {
    @StateObject private var viewModel = GroupViewModel()
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group information")) {
                    TextField("Group name", text: $viewModel.groupName)
                        .autocapitalization(.words)
                }
                
                Section {
                    Button("Create group") {
                        createGroup()
                    }
                    .disabled(viewModel.groupName.isEmpty || viewModel.isLoading)
                }
                
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                if let success = viewModel.successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Create group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func createGroup() {
        viewModel.createGroup { result in
            switch result {
            case .success:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    appState.refreshAuthState()
                    dismiss()
                }
            case .failure:
                // Error will already be displayed through viewModel.errorMessage
                break
            }
        }
    }
}
