// ReceiptScannerView.swift

import SwiftUI
import VisionKit
import Vision

struct ReceiptScannerView: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Binding var extractedFinanceRecord: FinanceRecord?
    @Environment(\.dismiss) var dismiss
    @State private var scannedImage: UIImage?

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: ReceiptScannerView

        init(_ parent: ReceiptScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Get first page image
            let image = scan.imageOfPage(at: 0)
            parent.scannedImage = image
            
            // Recognize text from image
            recognizeText(from: image)
            controller.dismiss(animated: true)
        }

        private func recognizeText(from image: UIImage) {
            guard let cgImage = image.cgImage else { return }

            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { [weak self] (request: VNRequest, error: Error?) in
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      error == nil else {
                    print("Error in text recognition: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                DispatchQueue.main.async {
                    print("Recognized text: \(text)")
                    self?.parent.recognizedText = text
                    // Extract receipt data after recognition
                    self?.extractReceiptData(from: text, image: image)
                }
            }

            request.recognitionLevel = .accurate

            do {
                try requestHandler.perform([request])
            } catch {
                print("Text recognition error: \(error)")
            }
        }

        private func extractReceiptData(from text: String, image: UIImage) {
            // Use ReceiptAnalyzer to extract data
            let receiptData = ReceiptAnalyzer.analyze(text: text)

            // If amount is found, create a finance record
            if let amount = receiptData.amount,
               let groupId = AppState.shared.user?.groupId {
                
                let recordId = UUID().uuidString
                var receiptPath: String? = nil
                
                // Save the scanned image
                if let savedPath = ReceiptStorage.saveReceipt(image: image, recordId: recordId) {
                    print("Receipt image saved at: \(savedPath)")
                    receiptPath = savedPath
                } else {
                    print("Failed to save receipt image")
                }

                let categoryString = receiptData.category ?? "Other"
                
                let record = FinanceRecord(
                    id: recordId,
                    type: .expense, // Default for receipts
                    amount: amount,
                    currency: "EUR", // Default currency
                    category: categoryString,
                    details: receiptData.merchantName ?? "",
                    date: receiptData.date ?? Date(),
                    receiptUrl: receiptPath,
                    groupId: groupId
                )

                print("Created finance record from receipt: \(record)")

                DispatchQueue.main.async {
                    self.parent.extractedFinanceRecord = record
                }
            } else {
                print("Could not extract necessary data from receipt. Amount: \(receiptData.amount ?? 0), GroupId: \(AppState.shared.user?.groupId ?? "nil")")
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scanner error: \(error)")
            controller.dismiss(animated: true)
        }
    }
}
