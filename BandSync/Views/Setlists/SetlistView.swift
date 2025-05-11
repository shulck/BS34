//
//  SetlistView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct SetlistView: View {
    @StateObject private var service = SetlistService.shared
    @State private var showAdd = false

    var body: some View {
        NavigationView {
            List {
                ForEach(service.setlists) { setlist in
                    NavigationLink(destination: SetlistDetailView(setlist: setlist)) {
                        VStack(alignment: .leading) {
                            Text(setlist.name)
                                .font(.headline)
                            Text("Duration: \(setlist.formattedTotalDuration)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .navigationTitle("Setlists")
            .toolbar {
                Button {
                    showAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    service.fetchSetlists(for: groupId)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddSetlistView()
            }
        }
    }
}

