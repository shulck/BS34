//
//  SellMerchView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct SellMerchView: View {
    @Environment(\.dismiss) var dismiss
    let item: MerchItem

    @State private var size = "M"
    @State private var quantity = 1
    @State private var channel: MerchSaleChannel = .concert
    @State private var isGift = false

    var body: some View {
        NavigationView {
            Form {
                // Only show size picker for clothing items
                if item.category == .clothing {
                    Picker("Size", selection: $size) {
                        ForEach(["S", "M", "L", "XL", "XXL"], id: \.self) { size in
                            Text(size)
                        }
                    }
                } else {
                    // For other categories we don't select size, using a dummy value
                    // This is hidden from the user
                    let _ = { size = "one_size" }()
                }

                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)

                Toggle("This is a gift", isOn: $isGift)
                    .onChange(of: isGift) { newValue in
                        if newValue {
                            channel = .gift
                        } else if channel == .gift {
                            channel = .concert
                        }
                    }

                if !isGift {
                    Picker("Sales channel", selection: $channel) {
                        ForEach(MerchSaleChannel.allCases.filter { $0 != .gift }) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }
                
                // Show sale total information
                if !isGift {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text("\(Double(quantity) * item.price, specifier: "%.2f") EUR")
                            .bold()
                    }
                } else {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text("Gift")
                            .bold()
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle(isGift ? "Gift item" : "Sale")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isGift ? "Gift" : "Confirm") {
                        // When gifting, forcibly set the channel to gift
                        let finalChannel = isGift ? MerchSaleChannel.gift : channel
                        MerchService.shared.recordSale(item: item, size: size, quantity: quantity, channel: finalChannel)
                        dismiss()
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
