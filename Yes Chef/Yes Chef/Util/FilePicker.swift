//
//  FilePicker.swift
//  Yes Chef
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FilePicker: UIViewControllerRepresentable {
    @Binding var fileData: Data?
    @Binding var mimeType: String?
    @Environment(\.dismiss) var dismiss

    private static let supportedMimeTypes: [String: String] = [
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "webp": "image/webp",
        "heic": "image/heic",
        "heif": "image/heif",
        "pdf": "application/pdf",
        "mp4": "video/mp4",
        "mpeg": "video/mpeg",
        "mpg": "video/mpeg",
        "mov": "video/mov",
        "avi": "video/avi",
        "flv": "video/x-flv",
        "webm": "video/webm",
        "wmv": "video/wmv",
        "3gp": "video/3gpp",
        "3gpp": "video/3gpp",
        "wav": "audio/wav",
        "mp3": "audio/mp3",
        "aiff": "audio/aiff",
        "aif": "audio/aiff",
        "aac": "audio/aac",
        "ogg": "audio/ogg",
        "flac": "audio/flac",
    ]

    private static let supportedImageMimeTypes: Set<String> = [
        "image/png", "image/jpeg", "image/webp", "image/heic", "image/heif"
    ]

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.image, .pdf, .movie, .audio]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePicker

        init(_ parent: FilePicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.dismiss()
            guard let url = urls.first else { return }

            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }

            guard let data = try? Data(contentsOf: url) else { return }

            let ext = url.pathExtension.lowercased()

            if let mime = FilePicker.supportedMimeTypes[ext] {
                // Supported type — pass through without conversion
                DispatchQueue.main.async {
                    self.parent.fileData = data
                    self.parent.mimeType = mime
                }
            } else if let image = UIImage(data: data),
                      let jpegData = image.jpegData(compressionQuality: 0.8) {
                // Unsupported image format (e.g. TIFF, BMP) — convert to JPEG
                DispatchQueue.main.async {
                    self.parent.fileData = jpegData
                    self.parent.mimeType = "image/jpeg"
                }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
