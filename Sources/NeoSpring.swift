import Foundation
import UIKit
import WebKit

/// SpringBoard-only restart method based on Erosion's NeoSpring/WebView method.
/// This differs from Diagnostics Relay "Restart", which reboots the full device.
@MainActor
enum NeoSpring {
    private static let document = """
    <!DOCTYPE html>
    <html>
        <body>
            <iframe id="frame" srcdoc="" sandbox="allow-forms allow-modals allow-orientation-lock allow-pointer-lock allow-popups allow-presentation allow-scripts"></iframe>
            <script>
                const frame = document.getElementById('frame');
                const respringScript = `
                    <html>
                    <body>
                        <script>
                            const container = document.createElement('div');
                            container.style.cssText = 'perspective: 1px; perspective-origin: 9999999% 9999999%;';
                            document.body.appendChild(container);

                            for (let i = 0; i < 500; i++) {
                                let d = document.createElement('div');
                                d.style.cssText = 'position: absolute; width: 100vw; height: 100vh; backdrop-filter: blur(100px); -webkit-backdrop-filter: blur(100px); transform: translate3d(100000px, 100000px, ' + i + 'px) rotateY(90deg);';
                                container.appendChild(d);
                            }

                            setInterval(() => {
                                navigator.share({ title: 'R', text: 'R'.repeat(100000) }).catch(() => {});
                                let x = new Uint8Array(1024 * 1024 * 10);
                                crypto.getRandomValues(x);
                            }, 0);
                        <\\/script>
                    </body>
                    </html>
                `;

                frame.srcdoc = respringScript;
            </script>
        </body>
    </html>
    """

    static func trigger() -> Bool {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard let window = windows.first(where: \.isKeyWindow) else { return false }

        let webView = WKWebView(frame: window.bounds)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = true
        webView.backgroundColor = .black
        window.addSubview(webView)
        webView.loadHTMLString(document, baseURL: nil)
        return true
    }
}
