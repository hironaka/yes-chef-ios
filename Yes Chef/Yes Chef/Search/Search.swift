//
//  Search.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 10/25/25.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    var onRecipeFound: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, onRecipeFound: onRecipeFound)
    }

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var parent: WebView
        var onRecipeFound: (String) -> Void

        init(_ parent: WebView, onRecipeFound: @escaping (String) -> Void) {
            self.parent = parent
            self.onRecipeFound = onRecipeFound
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("content loaded")
            
            let script = """
                (function() {
                    const scripts = document.querySelectorAll('script[type="application/ld+json"]');
                    for (const script of scripts) {
                        try {
                            const obj = JSON.parse(script.textContent);

                            // Handle direct recipe objects
                            if (obj && obj['@type']) {
                                const type = obj['@type'];
                                if (type === 'Recipe' || (Array.isArray(type) && type.includes('Recipe'))) {
                                    return JSON.stringify(obj);
                                }
                            }

                            // Handle @graph structure
                            if (obj && obj['@graph'] && Array.isArray(obj['@graph'])) {
                                const recipe = obj['@graph'].find(item => {
                                    const type = item['@type'];
                                    return type === 'Recipe' || (Array.isArray(type) && type.includes('Recipe'));
                                });
                                if (recipe) {
                                    return JSON.stringify(recipe);
                                }
                            }
                        } catch (e) {
                            // Ignore parsing errors
                        }
                    }
                    return null;
                })();
            """
            
            webView.evaluateJavaScript(script) { [weak self] (result, error) in
                print("JavaScript done: \(result)")
                
                if let error = error {
                    print("JavaScript evaluation failed: \(error.localizedDescription)")
                    return
                }
                
                if let recipeJSON = result as? String {
                    self?.onRecipeFound(recipeJSON)
                }
            }
        }
    }
}

struct Search: View {
    var body: some View {
        WebView(url: URL(string: "https://yes-chef.ai/search")!) { recipeJSON in
            print("Found recipe: \(recipeJSON)")
        }
    }
}

#Preview {
    Search()
}
