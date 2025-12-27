//
//  Search.swift
//  Yes Chef
//
//  Created by Hannah Hironaka on 10/25/25.
//

import SwiftData
import SwiftUI
import WebKit

class WebViewManager: ObservableObject {
    let webView: WKWebView

    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var recipe: String? = nil
    @Published var textContent: String? = nil
    @Published var canDownloadRecipe: Bool = false

    init() {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.customUserAgent =
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
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
        if let recipeJSON = self.recipe,
           let data = recipeJSON.data(using: .utf8) {
            do {
                let recipe = try JSONDecoder().decode(Recipe.self, from: data)
                completion(recipe)
                return
            } catch {
                print("Failed to decode recipe: \(error)")
            }
        }

        guard let text = self.textContent else {
            completion(nil)
            return
        }

        // Fallback to API
        print("Fallback extraction for text content")
        guard let url = URL(string: "https://yes-chef.ai/api/recipe/extract") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["textContent": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("API request failed: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            do {
                let response = try JSONDecoder().decode(APIRecipeResponse.self, from: data)
                if let recipe = response.toRecipe() {
                    DispatchQueue.main.async { completion(recipe) }
                } else {
                    print("API returned no recipe found")
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                print("Failed to decode recipe from API: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
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

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                print("Loading \(navigationAction.request)")
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                webView.load(navigationAction.request)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            webViewManager.canDownloadRecipe = false
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
        {
            print("content loaded")
            let script = """
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
                        
                        return {
                            recipe: recipe,
                            textContent: document.body.innerText
                        };
                    })();
                """

            webView.evaluateJavaScript(script) { [weak self] (result, error) in
                print("JavaScript done: \(result)")

                if let error = error {
                    print(
                        "JavaScript evaluation failed: \(error.localizedDescription)"
                    )
                    return
                }

                if let dict = result as? [String: Any] {
                    self?.webViewManager.recipe = dict["recipe"] as? String
                    self?.webViewManager.textContent = dict["textContent"] as? String
                    
                    let isYesChef = webView.url?.host == "yes-chef.ai"
                    let hasRecipe = self?.webViewManager.recipe != nil
                    let hasRecipeText = self?.webViewManager.textContent?.lowercased().contains("recipe") ?? false
                    
                    self?.webViewManager.canDownloadRecipe = !isYesChef && (hasRecipe || hasRecipeText)
                }

                self?.webViewManager.canGoBack = webView.canGoBack
                self?.webViewManager.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            webViewManager.canDownloadRecipe = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            webViewManager.canDownloadRecipe = false
        }
    }
}

struct Search: View {
    struct ToastConfig: Equatable {
        let type: ToastType
        let title: String
        let subtitle: String?
    }

    @Environment(\.modelContext) private var modelContext
    @StateObject private var webViewManager = WebViewManager()
    @State private var activeToast: ToastConfig?
    @State private var isDownloading = false
    @State private var downloadedRecipe: Recipe?

    private func showToast(type: ToastType, title: String, subtitle: String? = nil) {
        withAnimation {
            activeToast = ToastConfig(type: type, title: title, subtitle: subtitle)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WebView(
                    url: URL(string: "https://yes-chef.ai/search")!,
                    webViewManager: webViewManager
                )
                
                if let toast = activeToast {
                    VStack {
                        Spacer()
                        ToastView(
                            toastType: toast.type,
                            title: toast.title,
                            subtitle: toast.subtitle,
                            onUndo: {
                                withAnimation {
                                    activeToast = nil
                                }
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 50)
                    }
                    .id(toast.type)
                }

                if isDownloading {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Downloading recipe...")
                            .foregroundColor(.white)
                            .padding(.top, 10)
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(15)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            webViewManager.goBack()
                        }) {
                            Image(systemName: "arrow.left")
                        }
                        .disabled(!webViewManager.canGoBack)

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            webViewManager.goForward()
                        }) {
                            Image(systemName: "arrow.right")
                        }
                        .disabled(!webViewManager.canGoForward)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isDownloading = true
                        webViewManager.download { recipe in
                            isDownloading = false
                            if let recipe = recipe {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                downloadedRecipe = recipe
                            } else {
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                showToast(
                                    type: .error,
                                    title: "Download Failed",
                                    subtitle: "Could not extract recipe from this page."
                                )
                            }
                        }
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(!webViewManager.canDownloadRecipe)
                }
            }
            .sheet(item: $downloadedRecipe) { recipe in
                EditRecipeView(recipe: recipe)
            }
        }
    }
}

#Preview {
    Search()
}
