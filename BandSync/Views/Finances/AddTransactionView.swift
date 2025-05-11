// AddTransactionView.swift

import SwiftUI
import VisionKit

struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var type: FinanceType = .expense
    @State private var category: FinanceCategory = .logistics
    @State private var amount: String = ""
    @State private var currency: String = "EUR"
    @State private var details: String = ""
    @State private var date = Date()

    @State private var showReceiptScanner = false
    @State private var scannedText = ""
    @State private var extractedFinanceRecord: FinanceRecord?
    @State private var recognizedItems: [ReceiptItem] = []
    @State private var isLoadingTransaction = false
    @State private var errorMessage: String?

    private var isAmountValid: Bool {
        guard !amount.isEmpty else { return true }
        return Double(amount.replacingOccurrences(of: ",", with: ".")) != nil
    }

    private var formIsValid: Bool {
        return isAmountValid &&
               (!amount.isEmpty || extractedFinanceRecord != nil) &&
               !currency.isEmpty
    }

    private var currencies = ["EUR", "USD", "GBP"]

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
                        category = FinanceCategory.forType(newType).first ?? .logistics
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
                            .tag(cat)
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
                        Text("Invalid amount")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    TextField("Details", text: $details)

                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                }

                // Receipt Scanner Button
                Section {
                    Button(action: {
                        showReceiptScanner = true
                    }) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .foregroundColor(.blue)
                            Text("Scan Receipt")
                        }
                    }
                }

                // Scanned Text Display
                if !scannedText.isEmpty {
                    Section(header: Text("Receipt Text")) {
                        Text(scannedText)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // Display Extracted Record
                if let record = extractedFinanceRecord {
                    Section(header: Text("Recognized Data")) {
                        HStack {
                            Text("Amount")
                            Spacer()
                            Text("\(String(format: "%.2f", record.amount)) \(record.currency)")
                                .foregroundColor(record.type == .income ? .green : .red)
                        }

                        HStack {
                            Text("Category")
                            Spacer()
                            Text(record.category)
                        }

                        HStack {
                            Text("Date")
                            Spacer()
                            Text(formattedDate(record.date))
                        }
                        
                        if record.receiptUrl != nil {
                            HStack {
                                Text("Receipt")
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }

                        Button(action: {
                            amount = String(format: "%.2f", record.amount)
                            currency = record.currency
                            type = record.type
                            date = record.date
                            details = record.details

                            if let cat = FinanceCategory.allCases.first(where: { $0.rawValue == record.category }) {
                                category = cat
                            }
                        }) {
                            Label("Use this data", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Transaction")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRecord()
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
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScannerView(
                    recognizedText: $scannedText,
                    extractedFinanceRecord: $extractedFinanceRecord
                )
            }
        }
    }

    private func saveRecord() {
        isLoadingTransaction = true
        errorMessage = nil
        
        guard let groupId = AppState.shared.user?.groupId else {
            errorMessage = "User group not available"
            isLoadingTransaction = false
            return
        }

        let recordToSave: FinanceRecord

        if let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")), !amount.isEmpty {
            // Используем ID из извлеченной записи или создаем новый
            let recordId = extractedFinanceRecord?.id ?? UUID().uuidString
            
            // Используем URL чека из извлеченной записи, если доступен
            let receiptPath = extractedFinanceRecord?.receiptUrl
                
            recordToSave = FinanceRecord(
                id: recordId,
                type: type,
                amount: amountValue,
                currency: currency.uppercased(),
                category: category.rawValue,
                details: details,
                date: date,
                receiptUrl: receiptPath,
                groupId: groupId
            )
        } else if let extractedRecord = extractedFinanceRecord {
            recordToSave = extractedRecord
        } else {
            errorMessage = "No valid amount entered"
            isLoadingTransaction = false
            return
        }

        print("Saving record: \(recordToSave)")

        FinanceService.shared.add(recordToSave) { success in
            DispatchQueue.main.async {
                self.isLoadingTransaction = false
                
                if success {
                    print("Record saved successfully")
                    self.dismiss()
                } else {
                    self.errorMessage = "Failed to save transaction"
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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

extension Color {
    static let systemBackground = Color(UIColor.systemBackground)
}
