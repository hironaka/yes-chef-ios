//
//  Groceries.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 10/25/25.
//

import SwiftUI
import SwiftData

struct Groceries: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GroceryItem.timestamp, order: .forward) private var groceryItems: [GroceryItem]
    
    @State private var newItemName: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Add new item", text: $newItemName)
                            .submitLabel(.done)
                            .onSubmit {
                                addItem()
                            }
                        
                        Button(action: addItem) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                Section {
                    ForEach(groceryItems) { item in
                        HStack {
                            Button(action: {
                                toggleItem(item)
                            }) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCompleted ? .green : .gray)
                            }
                            .buttonStyle(.plain)
                            
                            Text(item.name)
                                .strikethrough(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .gray : .primary)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Groceries")
        }
    }
    
    private func addItem() {
        let trimmedName = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        withAnimation {
            let newItem = GroceryItem(name: trimmedName)
            modelContext.insert(newItem)
            newItemName = ""
        }
    }
    
    private func toggleItem(_ item: GroceryItem) {
        withAnimation {
            item.isCompleted.toggle()
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(groceryItems[index])
            }
        }
    }
}

#Preview {
    Groceries()
}
