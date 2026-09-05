// Tokens keep delayed work and JavaScript callbacks tied to the latest command.
struct PlaybackIntent {
    private(set) var generation = 0
    private(set) var pendingPlay = false
    private var inFlight = false
    private var retriesRemaining = 0

    mutating func begin(play: Bool) -> Int {
        generation += 1
        pendingPlay = play
        inFlight = false
        retriesRemaining = 2
        return generation
    }

    mutating func cancel() {
        _ = begin(play: false)
    }

    func isCurrent(_ token: Int) -> Bool {
        token == generation
    }

    mutating func startAttempt(_ token: Int) -> Bool {
        guard isCurrent(token), pendingPlay, !inFlight else { return false }
        inFlight = true
        return true
    }

    mutating func retry(_ token: Int) -> Bool {
        guard isCurrent(token), pendingPlay, inFlight else { return false }
        inFlight = false
        guard retriesRemaining > 0 else {
            pendingPlay = false
            return false
        }
        retriesRemaining -= 1
        return true
    }

    mutating func finish(_ token: Int) {
        guard isCurrent(token) else { return }
        pendingPlay = false
        inFlight = false
    }
}
