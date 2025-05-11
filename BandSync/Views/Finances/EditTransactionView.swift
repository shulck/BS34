//
//  EditTransactionView.swift
//  BandSyncApp
//
//  Created by Oleksandr Kuziakin on 10.05.2025.
//


// EditTransactionView.swift

import SwiftUI

struct EditTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var type: FinanceType
    @State private var category: String
    @State private var amount: String
    @State private var currency: String
    @State private var details: String
    @State private var date: Date
    @State private var isLoadingTransaction = false
    @State private var errorMessage: String?
    
    let record: FinanceRecord
    private var currencies = ["EUR", "USD", "GBP"]
    
    init(record: FinanceRecord) {
        self.record = record
        _type = State(initialValue: record.type)
        _category = State(initialValue: record.category)
        _amount = State(initialValue: String(format: "%.2f", record.amount))
        _currency = State(initialValue: record.currency)
        _details = State(initialValue: record.details)
        _date = State(initialValue: record.date)
    }
    
    private var isAmountValid: Bool {
        guard !amount.isEmpty else { return true }
        return Double(amount.replacingOccurrences(of: ",", with: ".")) != nil
    }
    
    private var formIsValid: Bool {
        return isAmountValid && !amount.isEmpty && !currency.isEmpty && !category.isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                // Transaction Type Picker
                Section {
                    Picker("Type", selection: $type) {
                        Text("Income").tag(FinanceType.income)
                        Text("Expense").tag(FinanceType.expense)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { newType in
                        if !FinanceCategory.forType(newType).contains(where: { $0.rawValue == category }) {
                            category = FinanceCategory.forType(newType).first?.rawValue ?? "Other"
                        }
                    }
                }

                // Category Picker
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(FinanceCategory.forType(type)) { cat in
                            HStack {
                                Image(systemName: categoryIcon(for: cat))
                                    .foregroundColor(categoryColor(for: cat))
                                Text(cat.rawValue)
                            }
                            .tag(cat.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Input Fields
                Section {
                    HStack {
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)

                        Picker("Currency", selection: $currency) {
                            ForEach(currencies, id: \.self) { curr in
                                Text(curr).tag(curr)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }

                    if !isAmountValid {
                        Text("Invalid amount format")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    TextField("Details", text: $details)

                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateRecord()
                    }
                    .disabled(!formIsValid || isLoadingTransaction)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoadingTransaction {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    ProgressView("Saving...")
                        .padding()
                        .background(Color.systemBackground)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
        }
    }

    private func updateRecord() {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Invalid amount format"
            return
        }
        
        isLoadingTransaction = true
        
        let updatedRecord = FinanceRecord(
            id: record.id,
            type: type,
            amount: amountValue,
            currency: currency.uppercased(),
            category: category,
            details: details,
            date: date,
            receiptUrl: record.receiptUrl,
            groupId: record.groupId
        )
        
        FinanceService.shared.update(updatedRecord) { success in
            isLoadingTransaction = false
            
            if success {
                dismiss()
            } else {
                errorMessage = "Failed to update transaction"
            }
        }
    }
    
    private func categoryIcon(for category: FinanceCategory) -> String {
        switch category {
        case .logistics: return "car.fill"
        case .food: return "fork.knife"
        case .gear: return "guitars"
        case .promo: return "megaphone.fill"
        case .other: return "ellipsis.circle.fill"
        case .performance: return "music.note"
        case .merch: return "tshirt.fill"
        case .accommodation: return "house.fill"
        case .royalties: return "music.quarternote.3"
        case .sponsorship: return "dollarsign.circle"
        }
    }

    private func categoryColor(for category: FinanceCategory) -> Color {
        switch category {
        case .logistics: return .blue
        case .food: return .orange
        case .gear: return .purple
        case .promo: return .green
        case .other: return .secondary
        case .performance: return .red
        case .merch: return .indigo
        case .accommodation: return .teal
        case .royalties: return .purple
        case .sponsorship: return .green
        }
    }
}