import UIKit
import WebKit

final class ViewController: UIViewController, WKNavigationDelegate {
    private var webView: WKWebView!

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadBundledApp()
    }

    private func loadBundledApp() {
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "app") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            return
        }

        let fallback = """
        <!doctype html>
        <html><meta name="viewport" content="width=device-width, initial-scale=1">
        <body style="font-family:-apple-system;padding:24px">
        <h2>刷题工具资源未找到</h2>
        <p>请确认 app/index.html 已打包进 IPA。</p>
        </body></html>
        """
        webView.loadHTMLString(fallback, baseURL: nil)
    }
}
