import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    private var webView: WKWebView!
    private let targetURL = "https://s4moflix.xyz"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        loadSite()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptEnabled = true

        // Permettre cookies et localStorage persistants
        let store = WKWebsiteDataStore.default()
        config.websiteDataStore = store

        // Préférences
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = true

        // Injecter le user-agent mobile
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 S4MoflixApp/1.0"

        view.addSubview(webView)
        view.backgroundColor = .black
    }

    private func loadSite() {
        guard let url = URL(string: targetURL) else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .useProtocolCachePolicy
        webView.load(request)
    }

    // Gestion des liens qui ouvrent une nouvelle fenêtre
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    // Page d'erreur si déconnecté
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showOfflinePage()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showOfflinePage()
    }

    private func showOfflinePage() {
        let html = """
        <html><body style="background:#0a0a0f;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;font-family:system-ui">
        <div style="text-align:center;color:#e2e8f0">
          <div style="font-size:60px;margin-bottom:16px">📡</div>
          <h2 style="font-size:22px;margin-bottom:8px">Connexion requise</h2>
          <p style="color:#64748b;font-size:14px;margin-bottom:24px">S4MOFLIX nécessite une connexion internet.</p>
          <button onclick="window.location.reload()" style="background:#6366f1;color:#fff;border:none;padding:12px 24px;border-radius:8px;font-size:15px;cursor:pointer">Réessayer</button>
        </div></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersHomeIndicatorAutoHidden: Bool { false }
}
