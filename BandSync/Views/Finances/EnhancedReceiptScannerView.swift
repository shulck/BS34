//
//  EnhancedReceiptScannerView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//


import SwiftUI
import VisionKit
import Vision
import NaturalLanguage

struct EnhancedReceiptScannerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var financeService = FinanceService.shared

    // Состояния для распознанных данных
    @State private var recognizedText = ""
    @State private var extractedAmount: Double?
    @State private var extractedDate: Date?
    @State private var extractedMerchant: String?
    @State private var extractedCategory: String?
    @State private var extractedItems: [String] = []

    // Состояния для редактирования
    @State private var type: FinanceType = .expense
    @State private var amount: String = ""
    @State private var currency: String = "EUR"
    @State private var category: String = ""
    @State private var details: String = ""
    @State private var date = Date()

    // Состояния интерфейса
    @State private var isScanning = false
    @State private var isProcessing = false
    @State private var isEditing = false
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var errorMessage: String?

    // Форматтер для даты
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Кнопки для сканирования
                    if !isEditing {
                        scanButtons
                    }

                    // Результат сканирования или форма редактирования
                    if isEditing {
                        editForm
                    } else if !recognizedText.isEmpty {
                        scanResultView
                    }

                    // Сообщение об ошибке
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Receipt")
            .toolbar {
                // Кнопки управления
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Save") {
                            saveRecord()
                        }
                        .disabled(amount.isEmpty || category.isEmpty)
                    } else if !recognizedText.isEmpty {
                        Button("Edit") {
                            prepareForEditing()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                VNDocumentCameraScannerView(recognizedText: $recognizedText)
                    .ignoresSafeArea()
                    .onDisappear {
                        if !recognizedText.isEmpty {
                            processRecognizedText()
                        }
                    }
            }
            .sheet(isPresented: $showGallery) {
                ImagePicker(recognizedText: $recognizedText)
                    .ignoresSafeArea()
                    .onDisappear {
                        if !recognizedText.isEmpty {
                            processRecognizedText()
                        }
                    }
            }
            .overlay(Group {
                if isProcessing {
                    ProgressView("Analyzing receipt...")
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            })
        }
    }

    // MARK: - UI Components

    // Кнопки сканирования
    private var scanButtons: some View {
        VStack(spacing: 15) {
            Button(action: {
                showCamera = true
            }) {
                HStack {
                    Image(systemName: "camera")
                    Text("Scan with Camera")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            Button(action: {
                showGallery = true
            }) {
                HStack {
                    Image(systemName: "photo")
                    Text("Choose from Gallery")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
    }

    // Отображение результатов сканирования
    private var scanResultView: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Заголовок
            Text("Scan Results")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            // Границы для результатов
            VStack(alignment: .leading, spacing: 10) {
                // Распознанная сумма
                HStack {
                    Text("Amount:")
                        .bold()
                    if let amount = extractedAmount {
                        Text("\(amount, specifier: "%.2f") \(currency)")
                            .foregroundColor(.green)
                    } else {
                        Text("Not recognized")
                            .foregroundColor(.orange)
                    }
                }

                // Распознанная дата
                HStack {
                    Text("Date:")
                        .bold()
                    if let date = extractedDate {
                        Text(dateFormatter.string(from: date))
                            .foregroundColor(.green)
                    } else {
                        Text("Not recognized")
                            .foregroundColor(.orange)
                    }
                }

                // Продавец
                HStack {
                    Text("Merchant:")
                        .bold()
                    if let merchant = extractedMerchant {
                        Text(merchant)
                            .foregroundColor(.green)
                            .lineLimit(1)
                    } else {
                        Text("Not recognized")
                            .foregroundColor(.orange)
                    }
                }

                // Предполагаемая категория
                HStack {
                    Text("Category:")
                        .bold()
                    if let category = extractedCategory {
                        Text(category)
                            .foregroundColor(.green)
                    } else {
                        Text("Not determined")
                            .foregroundColor(.orange)
                    }
                }

                // Распознанные товары
                if !extractedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Items:")
                            .bold()
                        ForEach(extractedItems.prefix(3), id: \.self) { item in
                            Text("• \(item)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if extractedItems.count > 3 {
                            Text("... and \(extractedItems.count - 3) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Распознанный текст
                VStack(alignment: .leading) {
                    Text("Recognized text:")
                        .bold()
                    ScrollView {
                        Text(recognizedText)
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(height: 100)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)

            // Кнопка для добавления транзакции
            Button(action: {
                prepareForEditing()
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Create Transaction")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top)
        }
    }

    // Форма редактирования
    private var editForm: some View {
        VStack(spacing: 15) {
            // Тип транзакции (обычно расход для чеков)
            Picker("Type", selection: $type) {
                Text("Income").tag(FinanceType.income)
                Text("Expense").tag(FinanceType.expense)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 5)

            // Поле суммы
            HStack {
                Text("Amount:")
                    .bold()
                    .frame(width: 80, alignment: .leading)

                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)

                TextField("EUR", text: $currency)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Поле даты
            HStack {
                Text("Date:")
                    .bold()
                    .frame(width: 80, alignment: .leading)

                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Поле категории
            HStack {
                Text("Category:")
                    .bold()
                    .frame(width: 80, alignment: .leading)

                // Получаем доступные категории из FinanceCatgory
                Picker("", selection: $category) {
                    ForEach(FinanceCategory.forType(type), id: \.self) { financeCategory in
                        Text(financeCategory.rawValue).tag(financeCategory.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Поле деталей
            VStack(alignment: .leading) {
                Text("Details:")
                    .bold()

                TextEditor(text: $details)
                    .frame(height: 100)
                    .padding(5)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }

            // Кнопка сохранения
            Button(action: {
                saveRecord()
            }) {
                Text("Save Transaction")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(amount.isEmpty || category.isEmpty)
            .padding(.top)
        }
    }

    // MARK: - Методы

    // Обработка распознанного текста
    private func processRecognizedText() {
        isProcessing = true

        // Используем отдельный поток для анализа
        DispatchQueue.global(qos: .userInitiated).async {
            // Анализируем текст с помощью ReceiptAnalyzer
            let receiptData = ReceiptAnalyzer.analyze(text: recognizedText)

            // Обновляем UI в главном потоке
            DispatchQueue.main.async {
                extractedAmount = receiptData.amount
                extractedDate = receiptData.date
                extractedMerchant = receiptData.merchantName
                extractedCategory = receiptData.category
                extractedItems = receiptData.items

                // Предварительно заполняем поля редактирования
                if let amount = extractedAmount {
                    self.amount = String(format: "%.2f", amount)
                }

                if let date = extractedDate {
                    self.date = date
                }

                if let category = extractedCategory {
                    self.category = category
                }

                // Формируем детали из продавца и товаров
                var detailsText = ""
                if let merchant = extractedMerchant {
                    detailsText += merchant
                }

                if !extractedItems.isEmpty {
                    if !detailsText.isEmpty {
                        detailsText += "\n"
                    }
                    detailsText += extractedItems.prefix(3).joined(separator: "\n")
                    if extractedItems.count > 3 {
                        detailsText += "\n..."
                    }
                }

                self.details = detailsText

                isProcessing = false
            }
        }
    }

    // Подготовка к редактированию
    private func prepareForEditing() {
        isEditing = true
    }

    // Сохранение записи
    private func saveRecord() {
        guard let amountValue = Double(amount),
              let groupId = AppState.shared.user?.groupId
        else {
            errorMessage = "Invalid amount or group ID"
            return
        }

        let record = FinanceRecord(
            type: type,
            amount: amountValue,
            currency: currency.uppercased(),
            category: category,
            details: details,
            date: date,
            receiptUrl: nil,
            groupId: groupId
        )

        // Заменяем FinanceValidator.isValid на базовую проверку
        guard record.amount > 0 && !record.currency.isEmpty && !record.category.isEmpty else {
            errorMessage = "Invalid record data"
            return
        }

        isProcessing = true
        FinanceService.shared.add(record) { success in
            isProcessing = false

            if success {
                dismiss()
            } else {
                errorMessage = "Failed to save record"
            }
        }
    }
}

// MARK: - Вспомогательные представления

// Представление для сканера документов VisionKit
struct VNDocumentCameraScannerView: UIViewControllerRepresentable {
    @Binding var recognizedText: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: VNDocumentCameraScannerView

        init(_ parent: VNDocumentCameraScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Берем только первую страницу для чека
            guard scan.pageCount > 0 else {
                controller.dismiss(animated: true)
                return
            }

            let image = scan.imageOfPage(at: 0)
            recognizeText(from: image)
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scanner error: \(error)")
            controller.dismiss(animated: true)
        }

        private func recognizeText(from image: UIImage) {
            guard let cgImage = image.cgImage else { return }

            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      error == nil else {
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                DispatchQueue.main.async {
                    self?.parent.recognizedText = text
                }
            }

            // Настройка запроса для лучшего распознавания
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            try? requestHandler.perform([request])
        }
    }
}

// Представление для выбора изображения из галереи
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Environment(\.presentationMode) var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                recognizeText(from: image)
            }

            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }

        private func recognizeText(from image: UIImage) {
            guard let cgImage = image.cgImage else { return }

            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      error == nil else {
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                DispatchQueue.main.async {
                    self?.parent.recognizedText = text
                }
            }

            // Настройка запроса для лучшего распознавания
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            try? requestHandler.perform([request])
        }
    }
}