import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    private var webView: WKWebView!
    private let targetURL = "https://s4moflix.xyz"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebView()
        loadSite()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let store = WKWebsiteDataStore.default()
        config.websiteDataStore = store

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        // Injection CSS/JS au chargement pour comportement app native
        let css = """
        * { -webkit-touch-callout: none !important; -webkit-user-select: none !important; }
        input, textarea { -webkit-user-select: text !important; }
        body { -webkit-text-size-adjust: none !important; }
        """
        let js = """
        (function() {
          var style = document.createElement('style');
          style.textContent = `\(css)`;
          document.head.appendChild(style);
          // Bloquer zoom via meta viewport
          var meta = document.querySelector('meta[name=viewport]');
          if (meta) meta.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
          // Empêcher les menus contextuels natifs
          document.addEventListener('contextmenu', function(e) { e.preventDefault(); }, true);
          document.addEventListener('selectstart', function(e) { if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'TEXTAREA') e.preventDefault(); }, true);
        })();
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self

        // Comportement scroll natif app
        webView.scrollView.bounces = false
        webView.scrollView.decelerationRate = .normal
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.allowsBackForwardNavigationGestures = false

        // Pas de zoom utilisateur
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false

        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 S4MoflixApp/1.0"

        view.addSubview(webView)

        // Layout full screen avec safe area
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func loadSite() {
        guard let url = URL(string: targetURL) else { return }
        webView.load(URLRequest(url: url))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            // Ouvrir les téléchargements dans Safari natif
            if url.pathExtension == "mp4" || url.absoluteString.contains("/api/prepare/file/") {
                UIApplication.shared.open(url)
            } else {
                webView.load(URLRequest(url: url))
            }
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.code != NSURLErrorCancelled { showOfflinePage() }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.code != NSURLErrorCancelled { showOfflinePage() }
    }

    private func showOfflinePage() {
        let html = """
        <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"></head>
        <body style="background:#0a0a0f;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;font-family:system-ui">
        <div style="text-align:center;color:#e2e8f0;padding:24px">
          <div style="font-size:56px;margin-bottom:16px">📡</div>
          <h2 style="font-size:20px;margin-bottom:8px">Pas de connexion</h2>
          <p style="color:#64748b;font-size:13px;margin-bottom:24px">S4MOFLIX nécessite une connexion internet.</p>
          <button onclick="window.location.reload()" style="background:#6366f1;color:#fff;border:none;padding:14px 28px;border-radius:12px;font-size:16px;cursor:pointer;font-weight:600">Réessayer</button>
        </div></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersHomeIndicatorAutoHidden: Bool { false }
    override var prefersStatusBarHidden: Bool { false }
}
