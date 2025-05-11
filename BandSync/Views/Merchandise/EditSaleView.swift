import SwiftUI

struct EditSaleView: View {
    @Environment(\.dismiss) var dismiss
    let sale: MerchSale
    let item: MerchItem

    @State private var size: String
    @State private var quantity: Int
    @State private var channel: MerchSaleChannel
    @State private var isUpdating = false
    @State private var showDeleteConfirmation = false
    @State private var isGift: Bool

    init(sale: MerchSale, item: MerchItem) {
        self.sale = sale
        self.item = item
        _size = State(initialValue: sale.size)
        _quantity = State(initialValue: sale.quantity)
        _channel = State(initialValue: sale.channel)
        _isGift = State(initialValue: sale.channel == .gift)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item information")) {
                    HStack {
                        Text("Item")
                        Spacer()
                        Text(item.name)
                            .foregroundColor(.secondary)
                    }

                    if let subcategory = item.subcategory {
                        HStack {
                            Text("Category")
                            Spacer()
                            Text("\(item.category.rawValue) • \(subcategory.rawValue)")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Category")
                            Spacer()
                            Text(item.category.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Price")
                        Spacer()
                        Text("\(Int(item.price)) EUR")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Sale date")
                        Spacer()
                        Text(formattedDate)
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Sale details")) {
                    // Only show size picker for clothing items
                    if item.category == .clothing {
                        Picker("Size", selection: $size) {
                            ForEach(["S", "M", "L", "XL", "XXL"], id: \.self) { size in
                                Text(size)
                            }
                        }
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

                    HStack {
                        Text("Total")
                        Spacer()
                        if isGift {
                            Text("Gift")
                                .bold()
                                .foregroundColor(.green)
                        } else {
                            Text("\(totalAmount, specifier: "%.2f") EUR")
                                .bold()
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete sale")
                            Spacer()
                        }
                    }
                }
            }
            .alert("Delete sale?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSale()
                }
            }
            .navigationTitle("Edit sale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateSale()
                    }
                    .disabled(isUpdating || !isChanged)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .overlay(
                Group {
                    if isUpdating {
                        ProgressView("Updating...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            )
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: sale.date)
    }

    private var totalAmount: Double {
        return Double(quantity) * item.price
    }

    private var isChanged: Bool {
        return size != sale.size ||
               quantity != sale.quantity ||
               channel != sale.channel
    }

    private func updateSale() {
        isUpdating = true

        // First cancel the old sale
        MerchService.shared.cancelSale(sale, item: item) { success in
            if success {
                // Then create a new one with updated data
                // If it's a gift, forcibly set the channel to gift
                let finalChannel = isGift ? MerchSaleChannel.gift : channel
                MerchService.shared.recordSale(item: item, size: size, quantity: quantity, channel: finalChannel)
                isUpdating = false
                dismiss()
            } else {
                isUpdating = false
                // Here you can add an error notification
            }
        }
    }

    private func deleteSale() {
        isUpdating = true
        MerchService.shared.cancelSale(sale, item: item) { success in
            isUpdating = false
            if success {
                dismiss()
            }
        }
    }
}
