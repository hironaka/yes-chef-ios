//
//  ModelContainer.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 1/10/26.
//

import SwiftData

extension ModelContainer {
    static var shared: ModelContainer = {
        let schema = Schema([
            Recipe.self,
            GroceryItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier("group.ai.yes-chef.Yes-Chef"))

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
