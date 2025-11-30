import WebKit

final class MonacoWebViewPool {
    static let shared = MonacoWebViewPool()

    private let lock = NSLock()

    private var idleEngines: [MonacoEngine] = []
    private var prewarming: [ObjectIdentifier: PrewarmingEntry] = [:]

    private struct PrewarmingEntry {
        let engine: MonacoEngine
        var targetProfile: MonacoEditorProfile
    }

    private init() {}

    func prewarm(profile: MonacoEditorProfile, count: Int = 1) {
        guard count > 0 else { return }

        lock.lock()
        let existingForProfile =
            idleEngines.filter { $0.lastProfile == profile }.count +
            prewarming.values.filter { $0.targetProfile == profile }.count
        lock.unlock()

        let missing = max(0, count - existingForProfile)
        guard missing > 0 else { return }

        for _ in 0..<missing {
            let engine = MonacoEngine()
            prewarmEngine(engine, profile: profile)
        }
    }

    func acquire(profile: MonacoEditorProfile) -> MonacoEngine {
        lock.lock()
        defer { lock.unlock() }

        let targetSyntax = profile.syntax

        func takeIdle(where predicate: (MonacoEngine) -> Bool) -> MonacoEngine? {
            if let idx = idleEngines.firstIndex(where: predicate) {
                return idleEngines.remove(at: idx)
            }
            return nil
        }

        func takePrewarming(matching predicate: (MonacoEditorProfile) -> Bool) -> MonacoEngine? {
            if let (id, entry) = prewarming.first(where: { predicate($0.value.targetProfile) }) {
                prewarming.removeValue(forKey: id)
                return entry.engine
            }
            return nil
        }

        if let engine = takeIdle(where: { $0.lastProfile == profile }) {
            return engine
        }

        if let engine = takeIdle(where: { $0.lastProfile?.syntax == targetSyntax }) {
            return engine
        }

        if let engine = takePrewarming(matching: { $0 == profile }) {
            return engine
        }

        if let engine = takePrewarming(matching: { $0.syntax == targetSyntax }) {
            return engine
        }

        return MonacoEngine()
    }

    func release(_ engine: MonacoEngine) {
        engine.prepareForReuse()

        lock.lock()
        idleEngines.append(engine)
        lock.unlock()
    }

    private func prewarmEngine(_ engine: MonacoEngine, profile: MonacoEditorProfile) {
        let id = ObjectIdentifier(engine)

        lock.lock()
        prewarming[id] = PrewarmingEntry(engine: engine, targetProfile: profile)
        lock.unlock()

        Task.detached { [weak self, weak engine] in
            guard let self, let engine else { return }

            let id = ObjectIdentifier(engine)

            self.lock.lock()
            let stillPrewarming = self.prewarming[id]?.engine === engine
            self.lock.unlock()
            guard stillPrewarming else { return }

            do {
                try await engine.configure(profile: profile, text: "", visible: false)
            } catch {
            }

            self.lock.lock()
            defer { self.lock.unlock() }

            guard let entry = self.prewarming[id], entry.engine === engine else {
                self.prewarming[id] = nil
                return
            }

            self.prewarming[id] = nil
            self.idleEngines.append(engine)
        }
    }
}
