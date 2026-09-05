@main
struct TestPlaybackIntent {
    static func main() {
        var intent = PlaybackIntent()

        // A pause during navigation or the post-load delay invalidates queued play.
        for _ in ["navigation", "delay"] {
            let queued = intent.begin(play: true)
            _ = intent.begin(play: false)
            precondition(!intent.startAttempt(queued))
        }

        let obsolete = intent.begin(play: true)
        precondition(intent.startAttempt(obsolete))
        intent.cancel() // An unrelated navigation also rejects an in-flight callback.
        precondition(!intent.isCurrent(obsolete))
        precondition(!intent.retry(obsolete))
        precondition(!intent.pendingPlay)

        let replacement = intent.begin(play: true)
        intent.finish(obsolete)
        precondition(intent.pendingPlay)
        precondition(intent.startAttempt(replacement))
        precondition(!intent.startAttempt(replacement)) // Duplicate load/delay callback.
        intent.finish(replacement)
        precondition(!intent.startAttempt(replacement)) // Success consumes the intent.

        let missing = intent.begin(play: true)
        for _ in 0..<2 {
            precondition(intent.startAttempt(missing))
            precondition(intent.retry(missing))
        }
        precondition(intent.startAttempt(missing))
        precondition(!intent.retry(missing))
        precondition(!intent.pendingPlay)
        precondition(!intent.startAttempt(missing))

        let canceledRetry = intent.begin(play: true)
        precondition(intent.startAttempt(canceledRetry))
        precondition(intent.retry(canceledRetry))
        _ = intent.begin(play: false)
        precondition(!intent.startAttempt(canceledRetry))
        precondition(!intent.retry(canceledRetry))

        let recovered = intent.begin(play: true)
        precondition(intent.startAttempt(recovered))
        intent.finish(recovered)
        testPlaybackWiring()
        print("test-playback: ok")
    }
}
