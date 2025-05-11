// TransactionDetailView.swift

import SwiftUI

struct TransactionDetailView: View {
    let record: FinanceRecord
    @Environment(\.dismiss) var dismiss
    @State private var showShareSheet = false
    @State private var showShareReceiptSheet = false
    @State private var exportedPDF: Data?
    @State private var showAnimatedDetails = false
    @State private var showDeleteConfirmation = false
    @State private var showEditTransaction = false
    @State private var showReceiptImage = false
    @State private var receiptImage: UIImage?
    @State private var isDeleting = false
    @State private var deleteError: String?

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Logistics": return "car.fill"
        case "Food": return "fork.knife"
        case "Equipment": return "guitars"
        case "Accommodation": return "house.fill"
        case "Promotion": return "megaphone.fill"
        case "Other": return "ellipsis.circle.fill"
        case "Performances": return "music.note"
        case "Merchandise": return "tshirt.fill"
        case "Royalties": return "music.quarternote.3"
        case "Sponsorship": return "dollarsign.circle"
        default: return "questionmark.circle"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title and amount with animation
                VStack(spacing: 8) {
                    Text("\(record.type == .income ? "+" : "-")\(String(format: "%.2f", record.amount)) \(record.currency)")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(record.type == .income ? .green : .red)
                        .padding(.top, 10)
                        .padding(.bottom, 2)

                    Text(formattedDate(record.date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    record.type == .income ? Color.green.opacity(0.2) : Color.red.opacity(0.2),
                                    Color.secondary.opacity(0.05)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    // Circular category indicator
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                        ZStack {
                            Circle()
                                .fill(record.type == .income ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                .frame(width: 50, height: 50)

                            Image(systemName: categoryIcon(for: record.category))
                                .font(.system(size: 24))
                                .foregroundColor(record.type == .income ? .green : .red)
                        }
                    }
                    .offset(y: 55),
                    alignment: .bottom
                )
                .padding(.bottom, 30)

                // Transaction details with animation
                VStack(alignment: .leading, spacing: 20) {
                    // Transaction type
                    detailRow(
                        icon: record.type == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                        iconColor: record.type == .income ? .green : .red,
                        title: "Type",
                        value: record.type == .income ? "Income" : "Expense"
                    )
                    .opacity(showAnimatedDetails ? 1 : 0)
                    .offset(x: showAnimatedDetails ? 0 : -20)
                    .animation(.easeOut.delay(0.1), value: showAnimatedDetails)

                    Divider()

                    // Category
                    detailRow(
                        icon: categoryIcon(for: record.category),
                        iconColor: .blue,
                        title: "Category",
                        value: record.category
                    )
                    .opacity(showAnimatedDetails ? 1 : 0)
                    .offset(x: showAnimatedDetails ? 0 : -20)
                    .animation(.easeOut.delay(0.2), value: showAnimatedDetails)

                    if !record.details.isEmpty {
                        Divider()

                        // Description
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                    .frame(width: 28, height: 28)

                                Text("Description")
                                    .font(.headline)
                            }

                            Text(record.details)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                                .padding(.leading, 34)
                        }
                        .opacity(showAnimatedDetails ? 1 : 0)
                        .offset(x: showAnimatedDetails ? 0 : -20)
                        .animation(.easeOut.delay(0.3), value: showAnimatedDetails)
                    }

                    if record.isCached == true {
                        Divider()

                        detailRow(
                            icon: "cloud.slash",
                            iconColor: .orange,
                            title: "Status",
                            value: "Waiting for synchronization",
                            valueColor: .orange
                        )
                        .opacity(showAnimatedDetails ? 1 : 0)
                        .offset(x: showAnimatedDetails ? 0 : -20)
                        .animation(.easeOut.delay(0.4), value: showAnimatedDetails)
                    }
                    
                    // Receipt section (if available)
                    if let receiptPath = record.receiptUrl, !receiptPath.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.text.viewfinder")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                    .frame(width: 28, height: 28)

                                Text("Receipt")
                                    .font(.headline)
                                
                                Spacer()
                                
                                // View Receipt Button
                                Button("View") {
                                    print("Loading receipt from path: \(receiptPath)")
                                    loadReceiptImage(from: receiptPath)
                                    showReceiptImage = true
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                
                                // Share Receipt Button
                                Button("Share") {
                                    print("Sharing receipt from path: \(receiptPath)")
                                    loadReceiptImage(from: receiptPath)
                                    if receiptImage != nil {
                                        showShareReceiptSheet = true
                                    }
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        .opacity(showAnimatedDetails ? 1 : 0)
                        .offset(x: showAnimatedDetails ? 0 : -20)
                        .animation(.easeOut.delay(0.5), value: showAnimatedDetails)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.secondary.opacity(0.05))
                )
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)

                // Action buttons
                HStack(spacing: 16) {
                    actionButton(
                        icon: "square.and.arrow.up",
                        title: "Share",
                        action: {
                            createPDF()
                        }
                    )
                    .opacity(showAnimatedDetails ? 1 : 0)
                    .scaleEffect(showAnimatedDetails ? 1 : 0.8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.5), value: showAnimatedDetails)

                    actionButton(
                        icon: "trash",
                        title: "Delete",
                        color: .red,
                        action: {
                            showDeleteConfirmation = true
                        }
                    )
                    .opacity(showAnimatedDetails ? 1 : 0)
                    .scaleEffect(showAnimatedDetails ? 1 : 0.8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.6), value: showAnimatedDetails)

                    actionButton(
                        icon: "pencil",
                        title: "Edit",
                        action: {
                            showEditTransaction = true
                        }
                    )
                    .opacity(showAnimatedDetails ? 1 : 0)
                    .scaleEffect(showAnimatedDetails ? 1 : 0.8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.7), value: showAnimatedDetails)
                }
                .padding(.top, 10)
                
                if let error = deleteError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Transaction Details")
        .overlay {
            if isDeleting {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                ProgressView("Deleting...")
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdf = exportedPDF {
                DocumentShareSheet(items: [pdf])
            }
        }
        .sheet(isPresented: $showShareReceiptSheet) {
            if let image = receiptImage {
                DocumentShareSheet(items: [image])
            }
        }
        .sheet(isPresented: $showEditTransaction) {
            EditTransactionView(record: record)
        }
        .sheet(isPresented: $showReceiptImage) {
            VStack {
                HStack {
                    Spacer()
                    
                    // Share button in receipt view
                    Button {
                        showReceiptImage = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showShareReceiptSheet = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    
                    // Close button
                    Button("Close") {
                        showReceiptImage = false
                    }
                    .padding()
                }
                
                if let image = receiptImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                            .padding()
                        
                        Text("Receipt image could not be loaded")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        if let path = record.receiptUrl {
                            Text("Path: \(path)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Record ID: \(record.id)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                
                Spacer()
            }
        }
        .onAppear {
            // Start animation with a small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showAnimatedDetails = true
            }
        }
        .alert("Are you sure you want to delete this transaction?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteTransaction()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // Load receipt image from path
    private func loadReceiptImage(from path: String) {
        // Clear any previous image
        receiptImage = nil
        
        // Try loading the image using ReceiptStorage
        receiptImage = ReceiptStorage.loadReceipt(path: path)
        
        // If failed, try using the record ID
        if receiptImage == nil {
            receiptImage = ReceiptStorage.loadReceipt(path: record.id)
            print("Tried loading by record ID: \(record.id), result: \(receiptImage != nil)")
        }
        
        // If still no image, check if we can load directly by ID as filename
        if receiptImage == nil {
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Could not access documents directory")
                return
            }
            
            let receiptsFolder = documentsDirectory.appendingPathComponent("receipts")
            let filename = "\(path).jpg"
            let fileURL = receiptsFolder.appendingPathComponent(filename)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                receiptImage = UIImage(contentsOfFile: fileURL.path)
                print("Loaded image directly by ID: \(receiptImage != nil)")
            }
        }
    }
    
    private func deleteTransaction() {
        isDeleting = true
        deleteError = nil
        
        // Удаляем чек если он есть
        if let receiptPath = record.receiptUrl, !receiptPath.isEmpty {
            ReceiptStorage.deleteReceipt(path: receiptPath)
        }
        
        // Вызываем метод удаления
        FinanceService.shared.delete(record) { success in
            DispatchQueue.main.async {
                self.isDeleting = false
                
                if success {
                    self.dismiss()
                } else {
                    self.deleteError = "Failed to delete the transaction. Please try again."
                }
            }
        }
    }

    // Modular component for displaying details row
    private func detailRow(icon: String, iconColor: Color, title: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.title2)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .foregroundColor(valueColor)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(valueColor.opacity(0.1))
                )
        }
    }

    // Modular component for action button
    private func actionButton(icon: String, title: String, color: Color = .blue, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }

    // Create PDF for export - adding crash protection
    private func createPDF() {
        guard let pdf = generateSafePDF() else { return }
        self.exportedPDF = pdf
        self.showShareSheet = true
    }

    // Separate method for safe PDF creation
    private func generateSafePDF() -> Data? {
        let formatter = DateFormatter()
        formatter.dateStyle = .long

        do {
            let pdfData = NSMutableData()
            UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: 595, height: 842), nil)
            UIGraphicsBeginPDFPage()

            let font = UIFont.systemFont(ofSize: 14)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left

            let titleFont = UIFont.boldSystemFont(ofSize: 24)

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .paragraphStyle: paragraphStyle
            ]

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]

            let title = "Financial Transaction"
            title.draw(in: CGRect(x: 50, y: 50, width: 495, height: 30), withAttributes: titleAttributes)

            var y = 100.0
            let lineHeight = 25.0

            let details = [
                "Type: \(record.type == .income ? "Income" : "Expense")",
                "Category: \(record.category)",
                "Amount: \(String(format: "%.2f", record.amount)) \(record.currency)",
                "Date: \(formatter.string(from: record.date))",
                "Description: \(record.details)"
            ]

            for detail in details {
                detail.draw(in: CGRect(x: 50, y: y, width: 495, height: lineHeight), withAttributes: attributes)
                y += lineHeight
            }
            
            // Add receipt image to PDF if available
            if let receiptPath = record.receiptUrl, !receiptPath.isEmpty {
                y += lineHeight
                
                "Receipt:".draw(in: CGRect(x: 50, y: y, width: 495, height: lineHeight), withAttributes: attributes)
                y += lineHeight
                
                if receiptImage == nil {
                    loadReceiptImage(from: receiptPath)
                }
                
                if let image = receiptImage {
                    let imageRect = CGRect(x: 50, y: y, width: 300, height: 300)
                    image.draw(in: imageRect)
                } else {
                    "Receipt image not available".draw(in: CGRect(x: 50, y: y, width: 495, height: lineHeight), withAttributes: attributes)
                }
            }

            UIGraphicsEndPDFContext()
            return pdfData as Data
        } catch {
            print("Error creating PDF: \(error)")
            return nil
        }
    }
}
