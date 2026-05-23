import AppKit
import WebKit

private let appURL = URL(string: "https://play.endel.io/en/soundscape/focus")!
private let stateURL = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Endelito", isDirectory: true)
    .appendingPathComponent("state.json", isDirectory: false)

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private var window: NSWindow?
    private var playerView: WKWebView?
    private var statusItem: NSStatusItem?
    private var dynamicMenu: [[String: Any]] = []
    private var playbackState = PlaybackState(isPlaying: false, muted: false)

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
            playerView?.reload()
        case "debug":
            debugPage()
        case "play", "pause", "mute", "unmute":
            sendPlaybackCommand(command)
        case "toggle":
            sendPlaybackCommand(playbackState.isPlaying ? "pause" : "play")
        case "toggle-mute":
            sendPlaybackCommand(playbackState.muted ? "unmute" : "mute")
        case "deeplink":
            if let url = components.queryItems?.first(where: { $0.name == "url" })?.value {
                sendDeepLink(url)
            }
        default:
            break
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
        configuration.websiteDataStore = .default()
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

        webView.load(URLRequest(url: appURL))

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
        menu.addItem(withTitle: playbackState.muted ? "Unmute" : "Mute", action: #selector(toggleMute(_:)), keyEquivalent: "")

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
        playerView?.reload()
    }

    @objc private func togglePlayback(_ sender: Any?) {
        sendPlaybackCommand(playbackState.isPlaying ? "pause" : "play")
    }

    @objc private func toggleMute(_ sender: Any?) {
        sendPlaybackCommand(playbackState.muted ? "unmute" : "mute")
    }

    @objc private func runDynamicMenuItem(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? String else {
            return
        }

        sendMenuCommand(action)
    }

    private func sendPlaybackCommand(_ action: String) {
        ensurePlayerLoaded(showWindow: false)
        switch action {
        case "play":
            playbackState = PlaybackState(isPlaying: true, muted: playbackState.muted)
        case "pause":
            playbackState = PlaybackState(isPlaying: false, muted: playbackState.muted)
        case "toggle":
            playbackState = PlaybackState(isPlaying: !playbackState.isPlaying, muted: playbackState.muted)
        case "mute":
            playbackState = PlaybackState(isPlaying: playbackState.isPlaying, muted: true)
        case "unmute":
            playbackState = PlaybackState(isPlaying: playbackState.isPlaying, muted: false)
        default:
            break
        }
        rebuildStatusMenu()
        writeState()

        if action == "play" || action == "pause" || action == "toggle" {
            clickPlaybackButton()
            return
        }

        let script = """
        (() => {
          window.__endelito?.playbackCommand?.(\(jsonString(action)));

          const media = document.querySelector('audio, video');
          const playbackButton = document.querySelector('button[data-analytics="btn_player_playback_control"]');
          const action = \(jsonString(action));

          if ((action === 'play' || action === 'pause' || action === 'toggle') && playbackButton) {
            playbackButton.click();
          }

          if (!media && !playbackButton) return { ok: false, reason: 'no-media' };

          if (action === 'play') {
            if (media) media.muted = false;
            media?.play?.().catch?.(() => {});
          } else if (action === 'pause') {
            media?.pause?.();
          } else if (action === 'mute') {
            if (media) media.muted = true;
          } else if (action === 'unmute') {
            if (media) media.muted = false;
          }

          return {
            ok: true,
            isPlaying: action === 'play' ? true : action === 'pause' ? false : typeof media?.paused === 'boolean' ? !media.paused : false,
            muted: action === 'mute' ? true : action === 'unmute' ? false : Boolean(media?.muted)
          };
        })()
        """

        self.playerView?.evaluateJavaScript(script, completionHandler: { result, error in
            if let error {
                NSLog("Endelito playback command failed: \(error)")
                self.writeDebug(["playbackError": String(describing: error)])
                return
            }

            self.writeDebug(["playbackResult": result ?? "nil"])

            guard let state = result as? [String: Any]
            else {
                return
            }

            if state["ok"] as? Bool != true {
                if action == "play", state["reason"] as? String == "no-media" {
                    self.playerView?.load(URLRequest(url: appURL))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.sendPlaybackCommand("play")
                    }
                }

                return
            }

            self.playbackState = PlaybackState(
                isPlaying: state["isPlaying"] as? Bool ?? self.playbackState.isPlaying,
                muted: state["muted"] as? Bool ?? self.playbackState.muted
            )
            self.rebuildStatusMenu()
            self.writeState()
        })
    }

    private func clickPlaybackButton() {
        let script = """
        (() => {
          const button = document.querySelector('button[data-analytics="btn_player_playback_control"]');
          if (!button) return { ok: false, reason: 'no-playback-button' };
          const rect = button.getBoundingClientRect();
          return {
            ok: true,
            x: rect.x + rect.width / 2,
            y: rect.y + rect.height / 2,
            width: rect.width,
            height: rect.height
          };
        })()
        """

        self.playerView?.evaluateJavaScript(script, completionHandler: { result, error in
            if let error {
                self.writeDebug(["nativeClickError": String(describing: error)])
                return
            }

            guard let rect = result as? [String: Any],
                  rect["ok"] as? Bool == true,
                  let x = rect["x"] as? Double,
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
        })
    }

    private func sendMenuCommand(_ action: String) {
        ensurePlayerLoaded(showWindow: false)
        evaluate("window.__endelito && window.__endelito.menuCommand(\(jsonString(action)))")
    }

    private func sendDeepLink(_ url: String) {
        ensurePlayerLoaded(showWindow: false)
        evaluate("window.__endelito && window.__endelito.deepLink(\(jsonString(url)))")
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
        let script = """
        (() => {
          const selectors = [
            'button',
            '[role="button"]',
            '[aria-label]',
            '[data-testid]',
            'audio',
            'video'
          ];
          const items = selectors.flatMap((selector) =>
            Array.from(document.querySelectorAll(selector)).slice(0, 80).map((element) => ({
              selector,
              tag: element.tagName,
              text: (element.innerText || element.textContent || '').trim().slice(0, 80),
              aria: element.getAttribute('aria-label'),
              className: String(element.className || '').slice(0, 160),
              title: element.getAttribute('title'),
              testid: element.getAttribute('data-testid'),
              role: element.getAttribute('role'),
              rect: (() => {
                const rect = element.getBoundingClientRect();
                return { x: Math.round(rect.x), y: Math.round(rect.y), width: Math.round(rect.width), height: Math.round(rect.height) };
              })(),
              html: element.outerHTML.slice(0, 300),
              paused: typeof element.paused === 'boolean' ? element.paused : null,
              muted: typeof element.muted === 'boolean' ? element.muted : null
            }))
          );
          return {
            href: location.href,
            title: document.title,
            readyState: document.readyState,
            hasElectron: Boolean(window.electron),
            hasEndelito: Boolean(window.__endelito),
            items
          };
        })()
        """

        playerView?.evaluateJavaScript(script) { result, error in
            if let error {
                self.writeDebug(["error": String(describing: error)])
                return
            }

            self.writeDebug(result ?? ["result": "nil"])
        }
    }

    private func writeDebug(_ value: Any) {
        let directory = stateURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("debug.json")

        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
        else {
            try? "\(value)".data(using: .utf8)?.write(to: url, options: [.atomic])
            return
        }

        try? data.write(to: url, options: [.atomic])
    }

    private func jsonString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let string = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }

        return string
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "endelito",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String
        else {
            return
        }

        switch type {
        case "playback":
            if let state = body["state"] as? [String: Any] {
                playbackState = PlaybackState(
                    isPlaying: state["isPlaying"] as? Bool ?? playbackState.isPlaying,
                    muted: state["muted"] as? Bool ?? playbackState.muted
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
        default:
            break
        }
    }

    private func writeState() {
        let directory = stateURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let payload: [String: Any] = [
            "app": "Endelito",
            "url": appURL.absoluteString,
            "isPlaying": playbackState.isPlaying,
            "muted": playbackState.muted,
            "dynamicMenuCount": dynamicMenu.count,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        try? data.write(to: stateURL, options: [.atomic])
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
    var muted: Bool
}

private let electronCompatibilityShim = """
(() => {
  if (window.electron && window.__endelito) return;

  const playbackCallbacks = new Set();
  const menuCallbacks = new Set();
  const deeplinkCallbacks = new Set();
  const post = (message) => {
    try {
      window.webkit?.messageHandlers?.endelito?.postMessage(message);
    } catch (_) {}
  };
  const unsubscribeFrom = (callbacks, cb) => () => callbacks.delete(cb);
  const noop = async () => {};
  const state = { playback: null, menu: [] };

  window.__endelito = {
    playbackCommand: (action) => {
      for (const cb of playbackCallbacks) cb(action);
      const media = document.querySelector('audio, video');
      if (!media) return;

      if (action === 'play') {
        media.muted = false;
        media.play?.().catch?.(() => {});
      } else if (action === 'pause') {
        media.pause?.();
      } else if (action === 'mute') {
        media.muted = true;
      } else if (action === 'unmute') {
        media.muted = false;
      }

      post({
        type: "playback",
        state: {
          isPlaying: typeof media.paused === 'boolean' ? !media.paused : false,
          muted: Boolean(media.muted)
        }
      });
    },
    menuCommand: (action) => {
      for (const cb of menuCallbacks) cb(action);
    },
    deepLink: (url) => {
      for (const cb of deeplinkCallbacks) cb(url);
      window.dispatchEvent(new CustomEvent("endelito:deeplink", { detail: url }));
    }
  };

  window.electron = {
    app: { getVersion: async () => "endelito/0.1.0" },
    iap: {
      canMakePayments: async () => false,
      getProducts: async () => [],
      buy: noop,
      restore: noop,
      onTransactionsUpdated: () => () => {},
      onPurchaseSuccess: () => () => {},
      onPurchaseFailed: () => () => {}
    },
    review: { requestReview: noop },
    playback: {
      updateState: async (nextState) => {
        state.playback = nextState;
        post({ type: "playback", state: nextState });
      },
      onCommand: (cb) => {
        playbackCallbacks.add(cb);
        return unsubscribeFrom(playbackCallbacks, cb);
      }
    },
    menu: {
      updateMenu: async (nextMenu) => {
        state.menu = nextMenu || [];
        post({ type: "menu", menu: state.menu });
      },
      onMenuCommand: (cb) => {
        menuCallbacks.add(cb);
        return unsubscribeFrom(menuCallbacks, cb);
      }
    },
    push: {
      register: noop,
      requestPermission: noop,
      getAuthorizationStatus: async () => "denied",
      onTokenUpdated: () => () => {},
      onAuthorizationStatusUpdated: () => () => {}
    },
    window: {
      onMinimize: () => () => {},
      onRestore: () => () => {},
      onMaximize: () => () => {},
      onUnmaximize: () => () => {},
      onShow: () => () => {},
      onHide: () => () => {},
      onFocus: () => () => {},
      onBlur: () => () => {},
      onEnterFullScreen: () => () => {},
      onLeaveFullScreen: () => () => {},
      onMove: () => () => {},
      onResize: () => () => {},
      onAlwaysOnTopChanged: () => () => {}
    },
    deeplinks: {
      onOpen: (cb) => {
        deeplinkCallbacks.add(cb);
        return unsubscribeFrom(deeplinkCallbacks, cb);
      }
    },
    oauth: {
      google: noop,
      facebook: noop,
      apple: noop,
      onSuccess: () => () => {}
    }
  };
})();
"""

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
