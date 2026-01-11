//
//  RecipeExtractor.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 11/1/25.
//

import Foundation
import WebKit

class RecipeExtractor: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var completion: ((Recipe?) -> Void)?
    private var isWorking = false
    
    // JS to extract recipe
    private let extractionScript = """
    (function() {
        let recipe = null;
        const scripts = document.querySelectorAll('script[type="application/ld+json"]');
        
        function findRecipe(obj) {
            if (!obj) return null;
            
            // Handle direct recipe objects
            if (obj['@type']) {
                const type = obj['@type'];
                if (type === 'Recipe' || (Array.isArray(type) && type.includes('Recipe'))) {
                    return JSON.stringify(obj);
                }
            }

            // Handle @graph structure
            if (obj['@graph'] && Array.isArray(obj['@graph'])) {
                const graphRecipe = obj['@graph'].find(item => {
                    const type = item['@type'];
                    return type === 'Recipe' || (Array.isArray(type) && type.includes('Recipe'));
                });
                if (graphRecipe) {
                    return JSON.stringify(graphRecipe);
                }
            }
            return null;
        }

        for (const script of scripts) {
            try {
                const data = JSON.parse(script.textContent);
                const items = Array.isArray(data) ? data : [data];
                
                for (const item of items) {
                    recipe = findRecipe(item);
                    if (recipe) break;
                }
            } catch (e) {}
            if (recipe) break;
        }
        
        function getRecipeTextContent() {
            const recipeSelectors = [
                '.recipe-callout',
                '.tasty-recipes',
                '.easyrecipe',
                '.innerrecipe',
                '.recipe-summary.wide',
                '.wprm-recipe-container',
                '.recipe-content',
                '.simple-recipe-pro',
                '.mv-recipe-card',
                'div[itemtype="http://schema.org/Recipe"]',
                'div[itemtype="https://schema.org/Recipe"]',
                'div.recipediv'
            ];
            
            const selectorString = recipeSelectors.join(', ');
            const matchedElements = document.querySelectorAll(selectorString);
            
            if (matchedElements.length > 0) {
                return Array.from(matchedElements)
                    .map(el => el.innerText || el.textContent || '')
                    .join('\\n\\n')
                    .replace(/\\s\\s+/g, ' ')
                    .trim();
            }
            
            return document.body.innerText;
        }

        return {
            recipe: recipe,
            textContent: getRecipeTextContent()
        };
    })();
    """
    
    func extract(from url: URL, completion: @escaping (Recipe?) -> Void) {
        self.completion = completion
        self.isWorking = true
        
        // Configure headless WebView
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView?.navigationDelegate = self
        self.webView?.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
        
        let request = URLRequest(url: url)
        self.webView?.load(request)
        
        // Timeout safeguard
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.isWorking == true {
                print("Extraction timed out")
                self?.finish(with: nil)
            }
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        processWebviewContent(webView)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Navigation failed: \(error)")
        finish(with: nil)
    }
    
    private func processWebviewContent(_ webView: WKWebView) {
        webView.evaluateJavaScript(extractionScript) { [weak self] (result, error) in
            if let error = error {
                print("JS evaluation failed: \(error)")
                self?.finish(with: nil)
                return
            }
            
            guard let dict = result as? [String: Any] else {
                self?.finish(with: nil)
                return
            }
            
            // 1. Try JSON-LD
            if let recipeJSON = dict["recipe"] as? String,
               let data = recipeJSON.data(using: .utf8) {
                do {
                    let recipe = try JSONDecoder().decode(Recipe.self, from: data)
                    self?.finish(with: recipe)
                    return
                } catch {
                    print("JSON-LD decode failed: \(error)")
                }
            }
            
            // 2. Fallback to API
            if let textContent = dict["textContent"] as? String {
                self?.extractFromAPI(text: textContent)
            } else {
                self?.finish(with: nil)
            }
        }
    }
    
    private func extractFromAPI(text: String) {
        guard let url = URL(string: "https://yes-chef.ai/api/recipe/extract") else {
            finish(with: nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["textContent": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("API error: \(error)")
                DispatchQueue.main.async { self?.finish(with: nil) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { self?.finish(with: nil) }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(APIRecipeResponse.self, from: data)
                DispatchQueue.main.async {
                    self?.finish(with: response.toRecipe())
                }
            } catch {
                print("API decode error: \(error)")
                DispatchQueue.main.async { self?.finish(with: nil) }
            }
        }.resume()
    }
    
    private func finish(with recipe: Recipe?) {
        guard isWorking else { return }
        isWorking = false
        completion?(recipe)
        // Keep webView alive until now
        webView = nil
        completion = nil
    }
}
