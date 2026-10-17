import SwiftUI
import WebKit
import Network

private func planetLog(_ value: String) {
    let url = TaskStore().directory.appendingPathComponent("planet-debug.txt")
    let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    try? (old + value + "\n").write(to: url, atomically: true, encoding: .utf8)
}

/// Serves only bundled 3D assets on loopback; no external service is needed.
final class PlanetAssetServer {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "PopDay.PlanetAssets")
    private let root = Bundle.main.resourceURL!.appendingPathComponent("Planet")
    func start(_ completion: @escaping (URL) -> Void) {
        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
            let listener = try NWListener(using: parameters, on: .any)
            self.listener = listener
            listener.stateUpdateHandler = { state in
                planetLog("listener \(state) port \(String(describing: listener.port))")
                if case .ready = state, let port = listener.port,
                   let url = URL(string: "http://127.0.0.1:\(port.rawValue)/index.html") {
                    DispatchQueue.main.async { planetLog("callback \(url)"); completion(url) }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: self?.queue ?? .global())
                self?.receive(connection, accumulated: Data())
            }
            listener.start(queue: queue)
        } catch { NSLog("Planet asset server: %@", error.localizedDescription) }
    }
    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var request = accumulated
            if let data { request.append(data) }
            guard request.count <= 16384, error == nil else { connection.cancel(); return }
            if request.range(of: Data("\r\n\r\n".utf8)) == nil {
                if complete { connection.cancel() } else { self.receive(connection, accumulated: request) }
                return
            }
            let line = String(data: request, encoding: .utf8)?.components(separatedBy: "\r\n").first ?? ""
            let fields = line.split(separator: " ")
            guard fields.count >= 2, fields[0] == "GET" else { connection.cancel(); return }
            let path = String(fields[1]).components(separatedBy: "?")[0].removingPercentEncoding ?? ""
            let file = self.root.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).standardizedFileURL
            let valid = file.path.hasPrefix(self.root.standardizedFileURL.path + "/")
            let body = valid ? (try? Data(contentsOf: file)) : nil
            let mime = ["html":"text/html; charset=utf-8", "js":"text/javascript; charset=utf-8", "glb":"model/gltf-binary", "svg":"image/svg+xml", "png":"image/png"][file.pathExtension] ?? "application/octet-stream"
            let content = body ?? Data("Not found".utf8)
            let header = "HTTP/1.1 \(body == nil ? "404 Not Found" : "200 OK")\r\nContent-Type: \(mime)\r\nContent-Length: \(content.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
            var response = Data(header.utf8); response.append(content)
            connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
    deinit { listener?.cancel() }
}

struct PlanetView: NSViewControllerRepresentable {
    var state: DayState
    var desktop = false
    var onReset: () -> Void = {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSViewController(context: Context) -> NSViewController {
        context.coordinator.onReset = onReset
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "ready")
        config.userContentController.add(context.coordinator, name: "resetform")
        config.userContentController.add(context.coordinator, name: "diagnostics")
        config.userContentController.addUserScript(WKUserScript(source: "window.addEventListener('error', e=>window.webkit.messageHandlers.diagnostics.postMessage(e.message)); window.addEventListener('unhandledrejection', e=>window.webkit.messageHandlers.diagnostics.postMessage(String(e.reason)));", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        if desktop { config.userContentController.addUserScript(WKUserScript(source: "window.desktopGadget=true;document.addEventListener('DOMContentLoaded',()=>document.documentElement.classList.add('desktop'));", injectionTime: .atDocumentStart, forMainFrameOnly: true)) }
        let web = WKWebView(frame: .zero, configuration: config)
        if desktop { web.setValue(false, forKey: "drawsBackground"); web.underPageBackgroundColor = .clear }
        web.frame = NSRect(x: 0, y: 0, width: 390, height: 300)
        context.coordinator.web = web
        web.navigationDelegate = context.coordinator
        context.coordinator.server.start { url in planetLog("load frame \(web.frame)"); web.load(URLRequest(url: url)) }
        let controller = NSViewController()
        controller.view = web
        return controller
    }
    func updateNSViewController(_ controller: NSViewController, context: Context) {
        context.coordinator.onReset = onReset
        let tasks: [[String: Any]] = state.tasks.map { ["id": $0.id.uuidString, "reward": $0.xp, "done": $0.done, "later": $0.later] }
        var payload: [String: Any] = ["xp": state.xp, "growthXP": state.growthXP, "tasks": tasks]
        if let event = state.lastCelebration {
            let today = state.tasks.filter { !$0.later }
            payload["celebration"] = ["id": event.id.uuidString, "timestamp": event.date.timeIntervalSince1970, "valid": !today.isEmpty && today.allSatisfy { $0.done }]
        }
        if let event = state.lastReward {
            payload["event"] = ["id": event.id.uuidString, "kind": event.kind.rawValue, "timestamp": event.date.timeIntervalSince1970, "taskID": event.taskID?.uuidString ?? ""]
        }
        if let data = try? JSONSerialization.data(withJSONObject: payload), let json = String(data: data, encoding: .utf8) {
            context.coordinator.pending = "window.nativeUpdate(\(json));"
            context.coordinator.send()
        }
    }
    static func dismantleNSViewController(_ controller: NSViewController, coordinator: Coordinator) {
        guard let web = controller.view as? WKWebView else { return }
        web.configuration.userContentController.removeScriptMessageHandler(forName: "ready")
        web.configuration.userContentController.removeScriptMessageHandler(forName: "resetform")
        web.stopLoading()
    }
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let server = PlanetAssetServer()
        weak var web: WKWebView?
        var pending = ""
        var ready = false
        var onReset: (() -> Void)?
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "resetform" { onReset?(); return }
            if message.name == "diagnostics" { planetLog("JS \(message.body)"); return }; ready = true; planetLog("JS ready window \(String(describing:web?.window)) hidden \(String(describing:web?.isHidden))"); send();
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { planetLog("loaded \(String(describing: webView.url)) frame \(webView.frame)"); webView.evaluateJavaScript("JSON.stringify({text:document.body.innerText,canvas:document.querySelector('canvas')?.getBoundingClientRect().toJSON(),update:typeof window.nativeUpdate})") { value,error in planetLog("DOM \(String(describing:value)) \(String(describing:error))") } }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { planetLog("FAILED \(error)") }
        func send() { if ready, !pending.isEmpty { web?.evaluateJavaScript(pending, completionHandler: nil) } }
    }
}
