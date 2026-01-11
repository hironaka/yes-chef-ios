//
//  ShareViewController.swift
//  Share Extension
//
//  Created by Hannah Hironaka on 1/10/26.
//

import UIKit
import Social
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private var recipeExtractor = RecipeExtractor()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Ensure the view background is clear so we can present our own UI
        view.backgroundColor = .clear
        
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = extensionItem.attachments?.first else {
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            print("No attached data")
            return
        }
        
        print("Attachment loaded: \(attachment)")
        if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (data, error) in
                // data might be a URL or an NSURL
                let url: URL? = (data as? URL) ?? (data as? NSURL) as URL?
                
                guard let url = url else {
                    print("Failed to load URL from attachment")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.extractRecipe(from: url)
                }
            }
        }
    }
    
    private func extractRecipe(from url: URL) {
        // Show a loading UI using hosting controller
        let rootView = ShareView(status: .extracting)
        let hostingController = UIHostingController(rootView: rootView)
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.backgroundColor = .clear
        hostingController.didMove(toParent: self)
        
        recipeExtractor.extract(from: url) { [weak self] recipe in
            guard let self = self else { return }
            
            if let recipe = recipe {
                self.saveRecipe(recipe)
                // Update UI to success
                hostingController.rootView = ShareView(status: .success(recipe.name ?? "Recipe"))
                
                // Close after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
            } else {
                // Update UI to error
                hostingController.rootView = ShareView(status: .error)
                
                // Close after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                }
            }
        }
    }
    
    private func saveRecipe(_ recipe: Recipe) {
        do {
            let container = ModelContainer.shared
            let context = ModelContext(container)
            context.insert(recipe)
            try context.save()
            print("Recipe saved to shared App Group")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("Failed to save recipe: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
