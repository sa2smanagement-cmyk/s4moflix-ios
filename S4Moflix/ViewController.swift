import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, UIScrollViewDelegate {

    private var webView: WKWebView!
    private let targetURL = "https://s4moflix.xyz"
    private var zoomTimer: Timer?

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
        config.websiteDataStore = WKWebsiteDataStore.default()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        // ── Script injecté AVANT le chargement du DOM ──────────────────────
        // Ceci s'exécute en premier, avant tout JS de la page
        let earlyScript = """
        (function() {
          // 1. Forcer font-size 16px sur inputs → empêche iOS d'auto-zoomer au focus
          var st = document.createElement('style');
          st.textContent = [
            'input, textarea, select { font-size: 16px !important; }',
            '* { -webkit-touch-callout: none !important; }',
            'input, textarea { -webkit-user-select: text !important; }',
            'body { -webkit-text-size-adjust: 100% !important; touch-action: pan-x pan-y !important; }'
          ].join('\\n');
          document.head.appendChild(st);

          // 2. Injecter/fixer le meta viewport IMMÉDIATEMENT
          function enforceViewport() {
            var meta = document.querySelector('meta[name=viewport]');
            var content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no';
            if (!meta) {
              meta = document.createElement('meta');
              meta.name = 'viewport';
              document.head.appendChild(meta);
            }
            meta.setAttribute('content', content);
          }
          enforceViewport();

          // 3. Observer les changements du meta viewport
          var mo = new MutationObserver(function(mutations) {
            mutations.forEach(function(m) {
              m.addedNodes && m.addedNodes.forEach && m.addedNodes.forEach(function(n) {
                if (n.name === 'viewport') enforceViewport();
              });
              if (m.type === 'attributes' && m.target && m.target.name === 'viewport') enforceViewport();
            });
          });
          document.addEventListener('DOMContentLoaded', function() {
            mo.observe(document.head, { childList: true, subtree: true, attributes: true, attributeFilter: ['content'] });
          });

          // 4. Ré-enforcer au focus/blur des inputs (empêche zoom résiduel)
          document.addEventListener('focusout', function(e) {
            if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') {
              enforceViewport();
              // Reset scroll position after keyboard closes
              setTimeout(function() {
                window.scrollTo(0, window.scrollY);
              }, 100);
            }
          }, true);

          // 5. Bloquer le pinch-zoom via touch events
          document.addEventListener('touchstart', function(e) {
            if (e.touches.length > 1) e.preventDefault();
          }, { passive: false, capture: true });

          document.addEventListener('touchmove', function(e) {
            if (e.touches.length > 1) e.preventDefault();
          }, { passive: false, capture: true });

          // 6. Ré-enforcer toutes les 2 secondes (backup)
          setInterval(enforceViewport, 2000);
        })();
        """
        let earlyUserScript = WKUserScript(
            source: earlyScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(earlyUserScript)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false

        // ── Bloquer le zoom natif UIScrollView ────────────────────────────
        webView.scrollView.bounces = false
        webView.scrollView.decelerationRate = .normal
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.delegate = self      // UIScrollViewDelegate pour bloquer zoom
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        enforceNoZoom()

        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 S4MoflixApp/1.0"

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Timer pour ré-enforcer le no-zoom toutes les secondes (le zoom peut être restauré par WebKit)
        zoomTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.enforceNoZoom()
        }
    }

    private func enforceNoZoom() {
        if webView.scrollView.zoomScale != 1.0 {
            webView.scrollView.setZoomScale(1.0, animated: false)
        }
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
    }

    // UIScrollViewDelegate - retourner nil empêche tout zoom
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return nil
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        scrollView.pinchGestureRecognizer?.isEnabled = false
        scrollView.setZoomScale(1.0, animated: false)
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        scrollView.setZoomScale(1.0, animated: false)
    }

    private func loadSite() {
        guard let url = URL(string: targetURL) else { return }
        var req = URLRequest(url: url)
        req.cachePolicy = .useProtocolCachePolicy
        webView.load(req)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if url.pathExtension == "mp4" || url.absoluteString.contains("/api/prepare/file/") {
                UIApplication.shared.open(url)
            } else {
                webView.load(URLRequest(url: url))
            }
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let e = error as NSError
        if e.code != NSURLErrorCancelled { showOfflinePage() }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let e = error as NSError
        if e.code != NSURLErrorCancelled { showOfflinePage() }
    }

    private func showOfflinePage() {
        let h = """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
        </head><body style="background:#0a0a0f;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;font-family:system-ui">
        <div style="text-align:center;color:#e2e8f0;padding:24px">
          <div style="font-size:56px;margin-bottom:16px">📡</div>
          <h2 style="font-size:20px;margin-bottom:8px">Pas de connexion</h2>
          <p style="color:#64748b;font-size:13px;margin-bottom:24px">S4MOFLIX nécessite une connexion internet.</p>
          <button onclick="window.location.reload()" style="background:#6366f1;color:#fff;border:none;padding:14px 28px;border-radius:12px;font-size:16px;cursor:pointer;font-weight:600">Réessayer</button>
        </div></body></html>
        """
        webView.loadHTMLString(h, baseURL: nil)
    }

    deinit { zoomTimer?.invalidate() }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersHomeIndicatorAutoHidden: Bool { false }
    override var prefersStatusBarHidden: Bool { false }
}
