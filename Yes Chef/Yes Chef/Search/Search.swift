//
//  Search.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 10/25/25.
//

import SwiftUI
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
}

struct WebView: UIViewRepresentable {
    let url: URL
    var onRecipeFound: (String) -> Void
    @ObservedObject var webViewManager: WebViewManager

    init(url: URL, onRecipeFound: @escaping (String) -> Void, webViewManager: WebViewManager) {
        self.url = url
        self.onRecipeFound = onRecipeFound
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
        Coordinator(self, webViewManager: webViewManager, onRecipeFound: onRecipeFound)
    }

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        var parent: WebView
        var onRecipeFound: (String) -> Void
        @ObservedObject var webViewManager: WebViewManager

        init(_ parent: WebView, webViewManager: WebViewManager, onRecipeFound: @escaping (String) -> Void) {
            self.parent = parent
            self.webViewManager = webViewManager
            self.onRecipeFound = onRecipeFound
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
                    self?.onRecipeFound(recipeJSON)
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
                    // download action
                }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .disabled(webViewManager.recipeFound == nil)
            }
            .padding()
            
            WebView(
                url: URL(string: "https://yes-chef.ai/search")!,
                onRecipeFound: { recipeJSON in
                    print("Found recipe: \(recipeJSON)")
                },
                webViewManager: webViewManager
            )
        }
    }
}

#Preview {
    Search()
}
