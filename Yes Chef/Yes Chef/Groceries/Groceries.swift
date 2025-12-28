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
    @State private var showClearConfirmation = false
    @State private var isAddingItem = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationStack {
            List {
                if isAddingItem {
                    TextField("Name", text: $newItemName)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addItem()
                        }
                        .onAppear {
                            isFocused = true
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        showClearConfirmation = true
                    }
                    .disabled(groceryItems.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            isAddingItem = true
                        }
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Clear All Items?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearAll()
                }
            } message: {
                Text("This will remove all items from your grocery list.")
            }
        }
    }

    
    private func clearAll() {
        withAnimation {
            for item in groceryItems {
                modelContext.delete(item)
            }
        }
    }
    
    private func addItem() {
        let trimmedName = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        withAnimation {
            let newItem = GroceryItem(name: trimmedName)
            modelContext.insert(newItem)
            newItemName = ""
            isAddingItem = false
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
