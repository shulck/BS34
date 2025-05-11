import SwiftUI

struct SalesHistoryView: View {
    @Environment(\.dismiss) var dismiss
    let item: MerchItem
    @StateObject private var merchService = MerchService.shared
    @State private var selectedSale: MerchSale?
    @State private var showEditSale = false

    var body: some View {
        NavigationView {
            List {
                if sales.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "bag")
                                .font(.system(size: 64))
                                .foregroundColor(.gray)
                            Text("No sales history")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding()
                } else {
                    ForEach(sales) { sale in
                        Button {
                            selectedSale = sale
                            showEditSale = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formattedDate(sale.date))
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    if item.category == .clothing {
                                        Text("Size: \(sale.size)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Text("Channel: \(sale.channel.rawValue)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(sale.quantity) pcs.")
                                        .font(.headline)

                                    Text("\(saleAmount(sale), specifier: "%.2f") EUR")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sales History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSale) {
            if let sale = selectedSale {
                EditSaleView(sale: sale, item: item)
            }
        }
    }

    private var sales: [MerchSale] {
        guard let itemId = item.id else { return [] }
        return merchService.getSalesForItem(itemId).sorted { $0.date > $1.date }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func saleAmount(_ sale: MerchSale) -> Double {
        return sale.channel == .gift ? 0 : Double(sale.quantity) * item.price
    }
}
