#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const source = fs.readFileSync(path.join(root, "app/Sources/Endelito/main.swift"), "utf8");
const section = (start, end) => {
  const from = source.indexOf(start);
  const to = source.indexOf(end, from + start.length);
  if (from < 0 || to < 0) throw new Error(`Missing production method boundary: ${start}`);
  return source.slice(from, to).replaceAll("private ", "").replaceAll("@objc ", "");
};
const methods = [
  section("    @objc private func reload", "    @objc private func togglePlayback"),
  section("    private func sendPlaybackCommand", "    private func loadSource"),
  section("    private func schedulePlay", "    private func sendMenuCommand"),
  section("    func webView(\n        _ webView: WKWebView,\n        didFinish", "    func webView(\n        _ webView: WKWebView,\n        createWebViewWith")
].join("\n");
// Only UI/environment effects are stubs. Command, timer, callback and navigation
// methods above are compiled verbatim from the production AppDelegate.
const fixture = String.raw`
import Foundation

extension Double { static func now() -> Double { 0 } }
final class DispatchQueue {
    static let main = DispatchQueue()
    var queued: [() -> Void] = []
    func asyncAfter(deadline: Double, execute: @escaping () -> Void) { queued.append(execute) }
    func tick() { let next = queued; queued = []; next.forEach { $0() } }
}
struct NSPoint { let x: Double; let y: Double }
struct NSEvent {
    enum Kind { case leftMouseDown, leftMouseUp }
    static func mouseEvent(with: Kind, location: NSPoint, modifierFlags: [Int], timestamp: Double,
                           windowNumber: Int, context: Int?, eventNumber: Int, clickCount: Int,
                           pressure: Double) -> NSEvent? { NSEvent() }
}
final class WKNavigation {}
final class WKWebView {
    var url: URL? = URL(string: "https://example.invalid/focus")
    var bounds: (height: Double, width: Double) = (600, 940)
    var window: (windowNumber: Int, unused: Int)? = (0, 0)
    var callbacks: [(Any?, Error?) -> Void] = []
    var clicks = 0
    var isLoading = false
    var nextNavigation = WKNavigation()
    func reload() -> WKNavigation? { isLoading = true; return nextNavigation }
    func evaluateJavaScript(_ script: String, completion: @escaping (Any?, Error?) -> Void) { callbacks.append(completion) }
    func respond(_ result: [String: Any]) { let callback = callbacks.removeFirst(); callback(result, nil) }
    func mouseDown(with: NSEvent) { clicks += 1 }
    func mouseUp(with: NSEvent) {}
}
struct PlaybackState { var isPlaying: Bool }
func jsonString(_ value: String) -> String { "\"" + value + "\"" }
final class WiringProbe {
    var playbackIntent = PlaybackIntent()
    var requestedNavigation: WKNavigation?
    var currentNavigation: WKNavigation?
    var playerView: WKWebView? = WKWebView()
    var playbackState = PlaybackState(isPlaying: false)
    var pageURL: URL?
    var sourceSlug = "focus"
    var debug: [[String: Any]] = []
    var writtenPlayback: [Bool] = []
    var menuPlayback: [Bool] = []
    func ensurePlayerLoaded(showWindow: Bool) {}
    func rebuildStatusMenu() { menuPlayback.append(playbackState.isPlaying) }
    func writeState() { writtenPlayback.append(playbackState.isPlaying) }
    func writeDebug(_ value: [String: Any]) { debug.append(value) }
    func sourceSlug(from: URL?) -> String? { nil }
    __METHODS__
}
func testPlaybackWiring() {
    let missing: [String: Any] = ["ok": false, "reason": "no-playback-button"]
    let rect: [String: Any] = ["ok": true, "x": 10.0, "y": 20.0]
    for finishBeforePause in [false, true] {
        let probe = WiringProbe()
        let view = probe.playerView!
        let nav = WKNavigation()
        probe.requestedNavigation = nav
        _ = probe.playbackIntent.begin(play: true)
        probe.webView(view, didStartProvisionalNavigation: nav)
        if finishBeforePause { probe.webView(view, didFinish: nav) }
        probe.sendPlaybackCommand("pause")
        if !finishBeforePause { probe.webView(view, didFinish: nav) }
        DispatchQueue.main.tick()
        precondition(view.callbacks.count == 1) // Only the explicit pause.
        precondition(!probe.playbackState.isPlaying)
    }
    let superseded = WiringProbe()
    let previousLoad = WKNavigation()
    let requestedLoad = WKNavigation()
    superseded.requestedNavigation = previousLoad
    _ = superseded.playbackIntent.begin(play: true)
    superseded.requestedNavigation = requestedLoad
    superseded.webView(superseded.playerView!, didStartProvisionalNavigation: previousLoad)
    precondition(superseded.playbackIntent.pendingPlay)
    precondition(superseded.requestedNavigation === requestedLoad)
    precondition(superseded.currentNavigation == nil)
    superseded.webView(superseded.playerView!, didStartProvisionalNavigation: requestedLoad)
    superseded.webView(superseded.playerView!, didFinish: requestedLoad)
    DispatchQueue.main.tick()
    precondition(superseded.playerView!.callbacks.count == 1)
    superseded.playerView!.respond(rect)
    precondition(superseded.playerView!.clicks == 1)

    let cold = WiringProbe()
    let initial = WKNavigation()
    cold.requestedNavigation = initial // ensurePlayerLoaded's initial load.
    cold.playerView!.isLoading = true
    cold.sendPlaybackCommand("play")
    cold.webView(cold.playerView!, didStartProvisionalNavigation: initial)
    precondition(cold.playbackIntent.pendingPlay)
    precondition(cold.playerView!.callbacks.isEmpty)
    cold.playerView!.isLoading = false
    cold.webView(cold.playerView!, didFinish: initial)
    DispatchQueue.main.tick()
    cold.playerView!.respond(rect)
    precondition(cold.playerView!.clicks == 1)
    cold.webView(cold.playerView!, didFinish: initial)
    DispatchQueue.main.tick()
    precondition(cold.playerView!.callbacks.isEmpty) // Successful intent consumed.

    let reloading = WiringProbe()
    reloading.sendPlaybackCommand("play")
    reloading.reload(nil)
    reloading.playerView!.respond(rect)
    precondition(reloading.playerView!.clicks == 0)
    reloading.sendPlaybackCommand("play")
    reloading.webView(reloading.playerView!, didStartProvisionalNavigation: reloading.playerView!.nextNavigation)
    precondition(reloading.playbackIntent.pendingPlay)

    let stale = WiringProbe()
    stale.sendPlaybackCommand("play")
    stale.sendPlaybackCommand("pause")
    stale.playerView!.respond(rect) // Old JS play callback must not click.
    precondition(stale.playerView!.clicks == 0)
    stale.playerView!.respond(["ok": true, "skipped": "already-paused"])

    let navigation = WiringProbe()
    navigation.sendPlaybackCommand("play")
    navigation.webView(navigation.playerView!, didStartProvisionalNavigation: WKNavigation())
    navigation.playerView!.respond(missing)
    DispatchQueue.main.tick()
    precondition(navigation.playerView!.callbacks.isEmpty)

    let obsolete = WiringProbe()
    let oldNav = WKNavigation()
    let newNav = WKNavigation()
    obsolete.currentNavigation = newNav
    _ = obsolete.playbackIntent.begin(play: true)
    obsolete.webView(obsolete.playerView!, didFinish: oldNav)
    DispatchQueue.main.tick()
    precondition(obsolete.playerView!.callbacks.isEmpty)
    precondition(obsolete.pageURL == nil)

    let pausedRetry = WiringProbe()
    pausedRetry.sendPlaybackCommand("play")
    pausedRetry.playerView!.respond(missing)
    pausedRetry.sendPlaybackCommand("pause")
    DispatchQueue.main.tick()
    precondition(pausedRetry.playerView!.callbacks.count == 1)
    precondition(!pausedRetry.playbackState.isPlaying)

    let retry = WiringProbe()
    retry.sendPlaybackCommand("play")
    for _ in 0..<3 {
        retry.playerView!.respond(missing)
        DispatchQueue.main.tick()
    }
    precondition(retry.playerView!.callbacks.isEmpty)
    precondition(!retry.playbackIntent.pendingPlay)
    precondition(!retry.playbackState.isPlaying)
    precondition(retry.writtenPlayback.last == false)
    precondition(retry.menuPlayback.last == false)
    precondition(retry.debug.last?["playbackError"] as? String == "no-playback-button")
    retry.sendPlaybackCommand("play")
    retry.playerView!.respond(rect)
    precondition(retry.playerView!.clicks == 1)
}
`.replace("__METHODS__", methods);
const build = path.join(root, "build");
fs.mkdirSync(build, { recursive: true });
const temporary = fs.mkdtempSync(path.join(build, "playback-test-"));
try {
  const generated = path.join(temporary, "Wiring.swift");
  const binary = path.join(temporary, "test-playback");
  fs.writeFileSync(generated, fixture);
  execFileSync("xcrun", ["swiftc", "app/Sources/Endelito/PlaybackIntent.swift", "tools/TestPlaybackIntent.swift", generated, "-o", binary], { cwd: root, stdio: "inherit" });
  execFileSync(binary, [], { stdio: "inherit" });
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
