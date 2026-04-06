//
//  PasteRecipeTextView.swift
//  Yes Chef
//

import SwiftUI

struct PasteRecipeTextView: View {
    @Environment(\.dismiss) var dismiss
    @State private var text = ""
    var onSubmit: (String) -> Void

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Paste Recipe")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            dismiss()
                            onSubmit(text)
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }
}
