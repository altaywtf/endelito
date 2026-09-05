import AppKit
import WebKit

private struct SourceDefinition: Decodable {
    let id: String
    let name: String
    let modality: String
}

private struct SourceCatalogFile: Decodable {
    let sources: [SourceDefinition]
    let aliases: [String: String]
}

private let defaultSourceSlug = "focus"
private let trustedWebHosts: Set<String> = ["play.endel.io", "endel.io"]
private let stateURL = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Endelito", isDirectory: true)
    .appendingPathComponent("state.json", isDirectory: false)
private let sessionStore = WKWebsiteDataStore.default()

private let sourceCatalog = loadSourceCatalog()
private let sourceDefinitions = sourceCatalog.sources
private let sourceNames = Dictionary(uniqueKeysWithValues: sourceDefinitions.map { ($0.id, $0.name) })
private let sourceAliases = sourceCatalog.aliases

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private var window: NSWindow?
    private var playerView: WKWebView?
    private var statusItem: NSStatusItem?
    private var dynamicMenu: [[String: Any]] = []
    private var playbackState = PlaybackState(isPlaying: false)
    private var sourceSlug = defaultSourceSlug
    private var pageURL: URL?
    private var playbackIntent = PlaybackIntent()
    private var requestedNavigation: WKNavigation?
    private var currentNavigation: WKNavigation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURL(event:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        buildMainMenu()
        buildStatusItem()
        ensurePlayerLoaded(showWindow: false)
        writeState()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPlayer(nil)
        return true
    }

    @objc private func handleURL(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard let rawURL = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let components = URLComponents(string: rawURL)
        else {
            return
        }

        handleCommand(components)
    }

    private func handleCommand(_ components: URLComponents) {
        let command = components.host ?? components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        writeDebug([
            "receivedCommand": command,
            "receivedAt": ISO8601DateFormatter().string(from: Date())
        ])

        switch command {
        case "launch":
            ensurePlayerLoaded(showWindow: false)
        case "show":
            showPlayer(nil)
        case "hide":
            hidePlayer(nil)
        case "quit":
            NSApp.terminate(nil)
        case "reload":
            reload(nil)
        case "debug":
            debugPage()
        case "play":
            if let source = queryValue("source", in: components) {
                loadSource(source, playAfterLoad: true)
            } else {
                sendPlaybackCommand(command)
            }
        case "pause":
            sendPlaybackCommand(command)
        case "toggle":
            sendPlaybackCommand(playbackState.isPlaying ? "pause" : "play")
        case "source", "soundscape":
            if let source = queryValue("slug", in: components) ?? queryValue("source", in: components) {
                loadSource(source, playAfterLoad: playbackState.isPlaying)
            }
        case "deeplink":
            if let url = components.queryItems?.first(where: { $0.name == "url" })?.value {
                sendDeepLink(url)
            }
        default:
            writeDebug([
                "ignoredCommand": command,
                "receivedAt": ISO8601DateFormatter().string(from: Date())
            ])
        }
    }

    private func ensurePlayerLoaded(showWindow: Bool) {
        if let window {
            if showWindow {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            return
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = sessionStore
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        controller.add(self, name: "endelito")
        controller.addUserScript(WKUserScript(
            source: electronCompatibilityShim,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        configuration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.contentView = webView
        window.minSize = NSSize(width: 940, height: 500)
        window.title = "Endelito"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self

        if showWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        requestedNavigation = webView.load(URLRequest(url: sourceURL(sourceSlug)))

        self.playerView = webView
        self.window = window
    }

    private func buildMainMenu() {
        let menu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Show Player", action: #selector(showPlayer(_:)), keyEquivalent: "o")
        appMenu.addItem(withTitle: "Hide Player", action: #selector(hidePlayer(_:)), keyEquivalent: "w")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Endelito", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        menu.addItem(appMenuItem)

        NSApp.mainMenu = menu
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(named: "MenuBarIconTemplate") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            item.button?.image = image
            item.button?.imagePosition = .imageOnly
        } else {
            item.button?.title = "e"
        }
        statusItem = item
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: playbackState.isPlaying ? "Pause" : "Play", action: #selector(togglePlayback(_:)), keyEquivalent: "")
        menu.addItem(sourceMenuItem())

        if !dynamicMenu.isEmpty {
            menu.addItem(NSMenuItem.separator())

            for item in dynamicMenu {
                guard let label = item["label"] as? String,
                      let action = item["action"] as? String
                else {
                    continue
                }

                let menuItem = NSMenuItem(title: label, action: #selector(runDynamicMenuItem(_:)), keyEquivalent: "")
                menuItem.representedObject = action
                menu.addItem(menuItem)
            }
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Show Player", action: #selector(showPlayer(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Reload", action: #selector(reload(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem?.menu = menu
    }

    @objc private func showPlayer(_ sender: Any?) {
        ensurePlayerLoaded(showWindow: true)
    }

    @objc private func hidePlayer(_ sender: Any?) {
        window?.orderOut(nil)
    }

    @objc private func reload(_ sender: Any?) {
        ensurePlayerLoaded(showWindow: false)
        playbackIntent.cancel()
        requestedNavigation = playerView?.reload()
    }

    @objc private func togglePlayback(_ sender: Any?) {
        sendPlaybackCommand(playbackState.isPlaying ? "pause" : "play")
    }

    @objc private func runDynamicMenuItem(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? String else {
            return
        }

        sendMenuCommand(action)
    }

    @objc private func selectSource(_ sender: NSMenuItem) {
        guard let source = sender.representedObject as? String else {
            return
        }

        loadSource(source, playAfterLoad: playbackState.isPlaying)
    }

    private func sourceMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Source: \(sourceName(sourceSlug))", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Source")
        var currentModality = ""

        for source in sourceDefinitions {
            let modalityTitle = modalityDisplayName(source.modality)
            if modalityTitle != currentModality {
                if !currentModality.isEmpty {
                    submenu.addItem(NSMenuItem.separator())
                }

                currentModality = modalityTitle
                let groupItem = NSMenuItem(title: currentModality, action: nil, keyEquivalent: "")
                groupItem.isEnabled = false
                submenu.addItem(groupItem)
            }

            let sourceItem = NSMenuItem(title: source.name, action: #selector(selectSource(_:)), keyEquivalent: "")
            sourceItem.representedObject = source.id
            sourceItem.state = source.id == sourceSlug ? .on : .off
            submenu.addItem(sourceItem)
        }

        item.submenu = submenu
        return item
    }

    private func sendPlaybackCommand(_ action: String) {
        ensurePlayerLoaded(showWindow: false)
        let generation = playbackIntent.begin(play: action == "play")
        switch action {
        case "play":
            playbackState = PlaybackState(isPlaying: true)
        case "pause":
            playbackState = PlaybackState(isPlaying: false)
        case "toggle":
            playbackState = PlaybackState(isPlaying: !playbackState.isPlaying)
        default:
            break
        }
        rebuildStatusMenu()
        writeState()

        if action == "play", playerView?.isLoading == true { return }
        if action == "play" || action == "pause" || action == "toggle" {
            if action != "play" || playbackIntent.startAttempt(generation) {
                clickPlaybackButton(action, generation: generation)
            }
            return
        }
    }

    private func loadSource(_ rawSource: String, playAfterLoad: Bool) {
        guard let source = normalizedSourceSlug(rawSource) else {
            writeDebug(["sourceError": "invalid-source", "source": rawSource])
            return
        }

        ensurePlayerLoaded(showWindow: false)
        _ = playbackIntent.begin(play: playAfterLoad)
        sourceSlug = source
        playbackState = PlaybackState(isPlaying: playAfterLoad)
        rebuildStatusMenu()
        writeState()
        requestedNavigation = playerView?.load(URLRequest(url: sourceURL(source)))
    }

    private func schedulePlay(after delay: TimeInterval, generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard self.playbackIntent.startAttempt(generation) else { return }
            self.clickPlaybackButton("play", generation: generation)
        }
    }

    private func clickPlaybackButton(_ action: String, generation: Int) {
        playerView?.evaluateJavaScript("__endelito.nativePlaybackClick(\(jsonString(action)))") { result, error in
            guard self.playbackIntent.isCurrent(generation) else { return }
            if let error {
                self.playbackIntent.finish(generation)
                self.writeDebug(["nativeClickError": String(describing: error)])
                return
            }

            guard let rect = result as? [String: Any],
                  rect["ok"] as? Bool == true
            else {
                self.writeDebug(["nativeClickResult": result ?? "nil"])
                if action == "play",
                   let result = result as? [String: Any],
                   result["reason"] as? String == "no-playback-button" {
                    if self.playbackIntent.retry(generation) {
                        self.schedulePlay(after: 2, generation: generation)
                    } else {
                        self.writeDebug(["playbackError": "no-playback-button", "recovery": "Show Player, then try play again."])
                    }
                } else {
                    self.playbackIntent.finish(generation)
                }
                return
            }

            self.playbackIntent.finish(generation)
            if rect["skipped"] != nil {
                self.writeDebug(["webViewClick": rect])
                return
            }

            guard let x = rect["x"] as? Double,
                  let y = rect["y"] as? Double,
                  let webView = self.playerView
            else {
                self.writeDebug(["nativeClickResult": result ?? "nil"])
                return
            }

            let point = NSPoint(x: x, y: webView.bounds.height - y)
            let timestamp = ProcessInfo.processInfo.systemUptime
            guard let down = NSEvent.mouseEvent(
                with: .leftMouseDown,
                location: point,
                modifierFlags: [],
                timestamp: timestamp,
                windowNumber: webView.window?.windowNumber ?? 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            ),
            let up = NSEvent.mouseEvent(
                with: .leftMouseUp,
                location: point,
                modifierFlags: [],
                timestamp: timestamp + 0.05,
                windowNumber: webView.window?.windowNumber ?? 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 0
            ) else {
                return
            }

            webView.mouseDown(with: down)
            webView.mouseUp(with: up)
            self.writeDebug(["webViewClick": ["x": x, "y": y]])
        }
    }

    private func sendMenuCommand(_ action: String) {
        ensurePlayerLoaded(showWindow: false)
        evaluate("window.__endelito && window.__endelito.menuCommand(\(jsonString(action)))")
    }

    private func sendDeepLink(_ url: String) {
        ensurePlayerLoaded(showWindow: false)
        evaluate("window.__endelito && window.__endelito.deepLink(\(jsonString(url)))")
    }

    private func queryValue(_ name: String, in components: URLComponents) -> String? {
        components.queryItems?.first(where: { $0.name == name })?.value
    }

    private func sourceURL(_ source: String) -> URL {
        URL(string: "https://play.endel.io/en/soundscape/\(source)")!
    }

    private func normalizedSourceSlug(_ rawSource: String) -> String? {
        var source = rawSource.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: source), url.scheme != nil {
            source = soundscapeSlug(from: url) ?? ""
            if source.isEmpty {
                return nil
            }
        }

        source = source
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: "-")
        guard !source.isEmpty else {
            return nil
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard source.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }

        let resolvedSource = sourceAliases[source] ?? source
        guard sourceNames[resolvedSource] != nil else {
            return nil
        }

        return resolvedSource
    }

    private func sourceName(_ source: String) -> String {
        sourceNames[source] ?? source
    }

    private func modalityDisplayName(_ modality: String) -> String {
        guard let first = modality.first else {
            return modality
        }
        return String(first).uppercased() + modality.dropFirst()
    }

    private func sourceSlug(from url: URL?) -> String? {
        guard let url else {
            return nil
        }

        return soundscapeSlug(from: url).flatMap(normalizedSourceSlug)
    }

    private func soundscapeSlug(from url: URL) -> String? {
        let components = url.pathComponents
        guard let index = components.firstIndex(of: "soundscape"),
              components.indices.contains(index + 1)
        else {
            return nil
        }

        return components[index + 1]
    }

    private func evaluate(_ source: String) {
        playerView?.evaluateJavaScript(source) { _, error in
            if let error {
                NSLog("Endelito JavaScript error: \(error)")
            }
        }
    }

    private func debugPage() {
        ensurePlayerLoaded(showWindow: false)
        playerView?.evaluateJavaScript("__endelito.debugPage()") { result, error in
            if let error {
                self.writeDebug(["error": String(describing: error)])
                return
            }

            self.writeDebug(result ?? ["result": "nil"])
        }
    }

    private func writeDebug(_ value: Any) {
        let directory = stateURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("Endelito failed to create debug directory: \(error)")
            return
        }
        let url = directory.appendingPathComponent("debug.json")

        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        else {
            do {
                try "\(value)".data(using: .utf8)?.write(to: url, options: [.atomic])
            } catch {
                NSLog("Endelito failed to write debug file: \(error)")
            }
            return
        }

        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            NSLog("Endelito failed to write debug file: \(error)")
        }
    }

    private func jsonString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]),
              let string = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }

        return string
    }

    private func isTrustedBridgeMessage(_ message: WKScriptMessage) -> Bool {
        let frame = message.frameInfo
        let host = frame.securityOrigin.host.lowercased()
        if trustedWebHosts.contains(host) || host.hasSuffix(".endel.io") {
            return true
        }

        // about:blank / empty host frames are ignored; only Endel origins may drive state.
        writeDebug([
            "ignoredBridgeMessage": true,
            "host": host,
            "isMainFrame": frame.isMainFrame
        ])
        return false
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "endelito",
              isTrustedBridgeMessage(message),
              let body = message.body as? [String: Any],
              let type = body["type"] as? String
        else {
            return
        }

        switch type {
        case "playback":
            if let state = body["state"] as? [String: Any] {
                playbackState = PlaybackState(
                    isPlaying: state["isPlaying"] as? Bool ?? playbackState.isPlaying
                )
                rebuildStatusMenu()
                writeState()
            }
        case "menu":
            if let menu = body["menu"] as? [[String: Any]] {
                dynamicMenu = menu
                rebuildStatusMenu()
                writeState()
            }
        case "source":
            if let source = body["source"] as? String,
               let normalizedSource = normalizedSourceSlug(source),
               normalizedSource != sourceSlug {
                let shouldResume = playbackState.isPlaying || body["wasPlaying"] as? Bool == true
                let generation = playbackIntent.begin(play: shouldResume)
                sourceSlug = normalizedSource
                rebuildStatusMenu()
                writeState()
                if shouldResume {
                    schedulePlay(after: 1, generation: generation)
                }
            }
        default:
            break
        }
    }

    private func writeState() {
        let directory = stateURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("Endelito failed to create state directory: \(error)")
            return
        }

        let liveURL = playerView?.url ?? pageURL
        let liveSource = sourceSlug(from: liveURL)
        let resolvedSource = liveSource ?? (liveURL == nil ? sourceSlug : "")
        let resolvedURL = liveURL?.absoluteString ?? sourceURL(sourceSlug).absoluteString

        let payload: [String: Any] = [
            "app": "Endelito",
            "url": resolvedURL,
            "source": resolvedSource,
            "sourceName": resolvedSource.isEmpty ? "" : sourceName(resolvedSource),
            "isPlaying": playbackState.isPlaying,
            "dynamicMenuCount": dynamicMenu.count,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            NSLog("Endelito failed to encode state.json")
            return
        }

        do {
            try data.write(to: stateURL, options: [.atomic])
        } catch {
            NSLog("Endelito failed to write state.json: \(error)")
        }
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        guard navigation === currentNavigation, requestedNavigation == nil else { return }
        pageURL = webView.url
        if let source = sourceSlug(from: webView.url) {
            sourceSlug = source
        }

        rebuildStatusMenu()
        writeState()

        if playbackIntent.pendingPlay {
            schedulePlay(after: 1, generation: playbackIntent.generation)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Source commands create their intent before calling load. Any other
        // document navigation supersedes work queued for the previous page.
        if navigation !== requestedNavigation {
            playbackIntent.cancel()
        }
        currentNavigation = navigation
        requestedNavigation = nil
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
        }

        return nil
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if url.scheme == "http" || url.scheme == "https" || url.scheme == "about" {
            decisionHandler(.allow)
            return
        }

        NSWorkspace.shared.open(url)
        decisionHandler(.cancel)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

private struct PlaybackState {
    var isPlaying: Bool
}

private let electronCompatibilityShim = loadElectronCompatibilityShim()

private func loadElectronCompatibilityShim() -> String {
    guard let url = Bundle.main.url(forResource: "EndelitoBridge", withExtension: "js"),
          let source = try? String(contentsOf: url, encoding: .utf8)
    else {
        NSLog("Endelito bridge script missing: EndelitoBridge.js")
        return "window.__endelito = window.__endelito || {};"
    }

    return source
}

private func loadSourceCatalog() -> SourceCatalogFile {
    guard let url = Bundle.main.url(forResource: "sources", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let catalog = try? JSONDecoder().decode(SourceCatalogFile.self, from: data),
          !catalog.sources.isEmpty
    else {
        NSLog("Endelito sources catalog missing or invalid; using Focus fallback")
        return SourceCatalogFile(
            sources: [SourceDefinition(id: "focus", name: "Focus", modality: "focus")],
            aliases: [:]
        )
    }

    return catalog
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
