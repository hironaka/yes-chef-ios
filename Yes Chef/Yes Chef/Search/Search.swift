//
//  Search.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 10/25/25.
//

import SwiftUI
import SwiftData
import WebKit

class WebViewManager: ObservableObject {
    let webView: WKWebView
    
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var recipeFound: String? = nil
    
    init() {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        self.webView = WKWebView(frame: .zero, configuration: config)
    }
    
    func load(url: URL) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    func goBack() {
        webView.goBack()
    }
    
    func goForward() {
        webView.goForward()
    }
    
    func download(completion: @escaping (Recipe?) -> Void) {
        guard let recipeJSON = self.recipeFound,
              let data = recipeJSON.data(using: .utf8) else {
            completion(nil)
            return
        }
        
        do {
            let recipe = try JSONDecoder().decode(Recipe.self, from: data)
            completion(recipe)
        } catch {
            print("Failed to decode recipe: \(error)")
            completion(nil)
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var webViewManager: WebViewManager

    init(url: URL, webViewManager: WebViewManager) {
        self.url = url
        self.webViewManager = webViewManager
    }

    func makeUIView(context: Context) -> WKWebView {
        webViewManager.webView.uiDelegate = context.coordinator
        webViewManager.webView.navigationDelegate = context.coordinator
        
        let request = URLRequest(url: url)
        webViewManager.webView.load(request)
        
        return webViewManager.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self, webViewManager: webViewManager)
    }

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var parent: WebView
        @ObservedObject var webViewManager: WebViewManager

        init(_ parent: WebView, webViewManager: WebViewManager) {
            self.parent = parent
            self.webViewManager = webViewManager
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                print("Loading \(navigationAction.request)")
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
                    self?.webViewManager.recipeFound = recipeJSON
                } else {
                    self?.webViewManager.recipeFound = nil
                }
                
                self?.webViewManager.canGoBack = webView.canGoBack
                self?.webViewManager.canGoForward = webView.canGoForward
            }
        }
    }
}

struct Search: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var webViewManager = WebViewManager()

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    webViewManager.goBack()
                }) {
                    Image(systemName: "arrow.left")
                }
                .disabled(!webViewManager.canGoBack)
                
                Button(action: {
                    webViewManager.goForward()
                }) {
                    Image(systemName: "arrow.right")
                }
                .disabled(!webViewManager.canGoForward)
                
                Spacer()
                
                Button(action: {
                    webViewManager.download { recipe in
                        if let recipe = recipe {
                            modelContext.insert(recipe)
                        }
                    }
                }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .disabled(webViewManager.recipeFound == nil)
            }
            .padding()
            
            WebView(
                url: URL(string: "https://yes-chef.ai/search")!,
                webViewManager: webViewManager
            )
        }
    }
}

#Preview {
    Search()
}
