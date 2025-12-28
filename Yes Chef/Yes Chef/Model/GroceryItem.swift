//
//  GroceryItem.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 12/28/25.
//

import Foundation
import SwiftData

@Model
class GroceryItem: Identifiable {
    var name: String
    var isCompleted: Bool
    var timestamp: Date
    
    init(name: String, isCompleted: Bool = false, timestamp: Date = Date()) {
        self.name = name
        self.isCompleted = isCompleted
        self.timestamp = timestamp
    }
}
