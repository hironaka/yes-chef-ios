//
//  AddGroceriesView.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 12/27/25.
//

import SwiftUI

struct AddGroceriesView: View {
    let groceries: [String]
    let onAdd: ([String]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedGroceries: Set<String>
    
    init(groceries: [String], onAdd: @escaping ([String]) -> Void, onCancel: @escaping () -> Void) {
        self.groceries = groceries
        self.onAdd = onAdd
        self.onCancel = onCancel
        _selectedGroceries = State(initialValue: Set(groceries))
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(groceries, id: \.self) { grocery in
                    HStack {
                        Text(grocery)
                        Spacer()
                        Image(systemName: selectedGroceries.contains(grocery) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedGroceries.contains(grocery) ? .accentColor : .gray)
                            .onTapGesture {
                                UISelectionFeedbackGenerator().selectionChanged()
                                toggleSelection(for: grocery)
                            }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UISelectionFeedbackGenerator().selectionChanged()
                        toggleSelection(for: grocery)
                    }
                }
            }
            .navigationTitle("Add to Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onCancel()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onAdd(Array(selectedGroceries))
                    }
                }
            }
        }
    }
    
    private func toggleSelection(for grocery: String) {
        if selectedGroceries.contains(grocery) {
            selectedGroceries.remove(grocery)
        } else {
            selectedGroceries.insert(grocery)
        }
    }
}

#Preview {
    AddGroceriesView(
        groceries: ["Milk", "Eggs", "Bread", "Butter"],
        onAdd: { _ in },
        onCancel: {}
    )
}
