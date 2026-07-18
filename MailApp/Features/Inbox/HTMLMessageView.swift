//
//  HTMLMessageView.swift
//  MailApp
//
//  Renders an HTML email body in a self-sizing, non-interactive web view.
//  JavaScript is disabled and link taps are intercepted to open in the
//  system browser instead of navigating in place.
//

import SwiftUI
import WebKit

struct HTMLMessageView: View {
    let html: String
    @State private var height: CGFloat = 200

    var body: some View {
        HTMLWebView(html: wrappedHTML, height: $height)
            .frame(height: height)
    }

    private var wrappedHTML: String {
        """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: 15px;
            line-height: 1.4;
            margin: 0;
            padding: 0;
            word-wrap: break-word;
            overflow-wrap: break-word;
          }
          img { max-width: 100%; height: auto; }
          table { max-width: 100%; }
          a { color: #007AFF; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """
    }
}

/// Many HTML emails use fixed-width layouts (tables, divs with hardcoded
/// pixel widths) that plain `max-width: 100%` CSS doesn't catch, so content
/// can end up wider than the screen and get clipped since the web view's own
/// scrolling is disabled. This measures the actual rendered content width
/// against the viewport and, if it overflows, scales the whole page down to
/// fit — then reports back the resulting (scaled) height so the SwiftUI
/// frame around the web view sizes correctly with nothing cut off.
private let fitToScreenAndMeasureJS = """
(function() {
  var doc = document.documentElement;
  var body = document.body;
  var contentWidth = Math.max(body.scrollWidth, doc.scrollWidth);
  var viewportWidth = doc.clientWidth;
  var scale = 1;
  if (contentWidth > viewportWidth && contentWidth > 0) {
    scale = viewportWidth / contentWidth;
    body.style.transformOrigin = 'top left';
    body.style.transform = 'scale(' + scale + ')';
    body.style.width = contentWidth + 'px';
  }
  var contentHeight = Math.max(body.scrollHeight, doc.scrollHeight);
  return contentHeight * scale;
})();
"""

#if os(iOS)
import UIKit

private struct HTMLWebView: UIViewRepresentable {
    let html: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: Self.configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    static var configuration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs
        return config
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var height: CGFloat
        init(height: Binding<CGFloat>) { _height = height }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(fitToScreenAndMeasureJS) { [weak self] result, _ in
                guard let number = result as? NSNumber else { return }
                DispatchQueue.main.async { self?.height = CGFloat(truncating: number) }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
#elseif os(macOS)
import AppKit

private struct HTMLWebView: NSViewRepresentable {
    let html: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: Self.configuration)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }

    static var configuration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs
        return config
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var height: CGFloat
        init(height: Binding<CGFloat>) { _height = height }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(fitToScreenAndMeasureJS) { [weak self] result, _ in
                guard let number = result as? NSNumber else { return }
                DispatchQueue.main.async { self?.height = CGFloat(truncating: number) }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
#endif
