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
        
        if Bundle.main.bundlePath.hasSuffix(".appex") {
            extractViaURLSession(from: url)
        } else {
            extractViaWebView(from: url)
        }
    }
    
    private func extractViaWebView(from url: URL) {
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
    
    private func extractViaURLSession(from url: URL) {
        print("DEBUG: Starting extractViaURLSession for \(url)")
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            print("DEBUG: URLSession completed")
            guard let self = self, self.isWorking else {
                print("DEBUG: self is nil or not working")
                return
            }
            
            if let error = error {
                print("DEBUG: URLSession error: \(error)")
                self.finish(with: nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: HTTP Status Code: \(httpResponse.statusCode)")
            } else {
                print("DEBUG: Response is not an HTTPURLResponse")
            }
            
            guard let data = data else {
                print("DEBUG: Data is nil")
                self.finish(with: nil)
                return
            }
            
            print("DEBUG: Received \(data.count) bytes of data")
            
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                print("DEBUG: Failed to decode data to String")
                self.finish(with: nil)
                return
            }
            
            print("DEBUG: Successfully decoded HTML, length: \(html.count)")
            
            // 1. Try JSON-LD
            print("DEBUG: Attempting to extract JSON-LD")
            if let recipe = self.extractRecipeFromJSONLD(html: html) {
                print("DEBUG: Successfully extracted recipe from JSON-LD")
                self.finish(with: recipe)
                return
            }
            
            print("DEBUG: JSON-LD extraction failed, falling back to API")
            // 2. Fallback to API
            let textContent = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression, range: nil)
                                  .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression, range: nil)
            
            print("DEBUG: Extracted text content for API, length: \(textContent.count)")
            print("DEBUG: \(textContent)")
            self.extractFromAPI(text: textContent)
        }.resume()
        
        // Timeout safeguard
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if self?.isWorking == true {
                print("Extraction timed out")
                self?.finish(with: nil)
            }
        }
    }
    
    private func extractRecipeFromJSONLD(html: String) -> Recipe? {
        let pattern = "<script[^>]*type=\"application/ld\\+json\"[^>]*>(.*?)</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            print("DEBUG: Failed to compile JSON-LD regex")
            return nil
        }
        
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        print("DEBUG: Found \(matches.count) JSON-LD script tags")
        
        for (index, match) in matches.enumerated() {
            let jsonString = nsString.substring(with: match.range(at: 1))
            // print("DEBUG: JSON-LD match \(index) snippet: \(String(jsonString.prefix(100)))...")
            
            if let data = jsonString.data(using: .utf8) {
                do {
                    // JSON-LD can be an object or an array of objects
                    if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        if let recipe = parseRecipeJSON(jsonObject) { return recipe }
                    } else if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        for item in jsonArray {
                            if let recipe = parseRecipeJSON(item) { return recipe }
                        }
                    }
                } catch {
                    print("DEBUG: JSON parse error in script \(index): \(error)")
                }
            } else {
                print("DEBUG: Failed to encode JSON-LD string to data in script \(index)")
            }
        }
        
        print("DEBUG: No recipe found in any JSON-LD tag")
        return nil
    }
    
    private func parseRecipeJSON(_ obj: [String: Any]) -> Recipe? {
        if let type = obj["@type"] as? String, type == "Recipe" {
            return decodeRecipe(obj)
        } else if let type = obj["@type"] as? [String], type.contains("Recipe") {
            return decodeRecipe(obj)
        }
        
        if let graph = obj["@graph"] as? [[String: Any]] {
            for item in graph {
                if let type = item["@type"] as? String, type == "Recipe" {
                    return decodeRecipe(item)
                } else if let type = item["@type"] as? [String], type.contains("Recipe") {
                    return decodeRecipe(item)
                }
            }
        }
        return nil
    }
    
    private func decodeRecipe(_ obj: [String: Any]) -> Recipe? {
        do {
            let data = try JSONSerialization.data(withJSONObject: obj, options: [])
            return try JSONDecoder().decode(Recipe.self, from: data)
        } catch {
            print("Failed to decode recipe: \(error)")
            return nil
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
        print("DEBUG: Sending text to API, length: \(text.count)")
        guard let url = URL(string: "https://yes-chef.ai/api/recipe/extract") else {
            print("DEBUG: API URL is invalid")
            finish(with: nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["textContent": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            print("DEBUG: API request completed")
            if let error = error {
                print("DEBUG: API error: \(error)")
                DispatchQueue.main.async { self?.finish(with: nil) }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: API HTTP Status Code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("DEBUG: API returned nil data")
                DispatchQueue.main.async { self?.finish(with: nil) }
                return
            }
            
            print("DEBUG: API returned \(data.count) bytes of data")
            
            do {
                let response = try JSONDecoder().decode(APIRecipeResponse.self, from: data)
                print("DEBUG: Successfully decoded APIRecipeResponse: \(response)")
                DispatchQueue.main.async {
                    self?.finish(with: response.toRecipe())
                }
            } catch {
                print("DEBUG: API decode error: \(error)")
                if let str = String(data: data, encoding: .utf8) {
                    print("DEBUG: API raw response: \(str)")
                }
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
