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
    @Query(sort: \GroceryItem.timestamp, order: .reverse) private var groceryItems: [GroceryItem]
    
    @State private var showClearConfirmation = false
    @FocusState private var focusedField: PersistentIdentifier?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(groceryItems) { item in
                        HStack {
                            Button(action: {
                                toggleItem(item)
                            }) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(item.isCompleted ? .accentColor : .gray)
                            }
                            .buttonStyle(.plain)
                            
                            
                            TextField("Name", text: Bindable(item).name)
                                .focused($focusedField, equals: item.persistentModelID)
                                .strikethrough(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .gray : .primary)
                                .submitLabel(.done)
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
                        addItem()
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
        withAnimation {
            let newItem = GroceryItem(name: "")
            modelContext.insert(newItem)
            // Focus the new item
            focusedField = newItem.persistentModelID
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
