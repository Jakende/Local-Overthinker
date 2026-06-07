import AppKit
import Combine
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var state: AppState
    @Published var manualNote = ""
    @Published var archiveQuery = "" {
        didSet {
            Task { @MainActor in
                await refreshArchiveResultsAsync()
            }
        }
    }
    @Published private(set) var archiveResults: [ReflectionRecord] = []
    @Published private(set) var jobState: JobState = .idle
    @Published private(set) var jobMessage = "Quietly waiting for new clipboard activity."
    @Published private(set) var ollamaStatus: OllamaStatus = .checking
    @Published private(set) var lastBackgroundCaptureAt: Date?
    @Published private(set) var clipboardStatus: ClipboardSourceStatus = .inactive
    @Published private(set) var availableOllamaModels: [String] = []
    @Published private(set) var logEntries: [LogEntry] = []
    @Published var selectedReflectionID: UUID?

    private let systemPrompt = ReflectionEngine.loadSystemPrompt()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var clipboardTimer: Timer?
    private var reflectionTimer: Timer?
    private var lastClipboardText = ""
    private var queuedReflection = false
    private var isRunningReflection = false
    private let persistenceEnabled: Bool

    static let reflectionWindow: TimeInterval = 10 * 60

    init(initialState: AppState? = nil, shouldStartServices: Bool = true, persistenceEnabled: Bool = true) {
        self.persistenceEnabled = persistenceEnabled
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let initialState {
            state = initialState
        } else if let data = try? Data(contentsOf: AppPaths.stateFileURL),
           let saved = try? decoder.decode(AppState.self, from: data) {
            state = saved
        } else {
            state = ReflectionEngine.buildInitialState()
        }

        refreshArchiveResults()
        addLog(.info, "App started")
        if shouldStartServices {
            startServices()
        }
    }

    deinit {
        clipboardTimer?.invalidate()
        reflectionTimer?.invalidate()
    }

    private var client: OllamaClient {
        OllamaClient(settings: state.ollamaSettings)
    }

    var currentSession: Session? {
        state.sessions.first(where: { $0.id == state.currentSessionId })
    }

    var activeSession: Session? {
        state.sessions
            .filter { $0.status == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }

    var sessionHistory: [Session] {
        state.sessions.sorted { left, right in
            if left.status != right.status {
                return left.status == .active
            }

            return left.updatedAt > right.updatedAt
        }
    }

    var isViewingArchivedSession: Bool {
        currentSession?.status == .archived
    }

    var canEditCurrentSession: Bool {
        currentSession?.status == .active
    }

    var currentArtifacts: [Artifact] {
        guard let sessionID = currentSession?.id else { return [] }
        return state.artifacts
            .filter { $0.sessionId == sessionID && !$0.deleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var currentReflections: [ReflectionRecord] {
        guard let sessionID = currentSession?.id else { return [] }
        return state.reflections
            .filter { $0.sessionId == sessionID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var latestReflection: ReflectionRecord? {
        currentReflections.first
    }

    var displayedReflection: ReflectionRecord? {
        if let selectedReflectionID {
            return state.reflections.first(where: { $0.id == selectedReflectionID }) ?? latestReflection
        }

        return latestReflection
    }

    var nextReflectionDate: Date? {
        state.lastReflectionRunAt?.addingTimeInterval(Self.reflectionWindow)
    }

    var ollamaSettings: OllamaSettings {
        state.ollamaSettings
    }

    var automaticReflectionStatusText: String {
        guard canEditCurrentSession else {
            return "Paused while browsing archived sessions"
        }

        guard let pendingDate = latestPendingClipboardCaptureDate else {
            return "Waiting for new clipboard captures"
        }

        if let lastRun = state.lastReflectionRunAt, pendingDate <= lastRun {
            return "Clipboard is up to date"
        }

        let dueDate: Date
        if let lastRun = state.lastReflectionRunAt {
            dueDate = max(lastRun.addingTimeInterval(Self.reflectionWindow), pendingDate)
        } else {
            dueDate = pendingDate.addingTimeInterval(Self.reflectionWindow)
        }

        if dueDate <= Date() {
            return "A background reflection is due"
        }

        return "Next automatic reflection \(relativeLabel(for: dueDate))"
    }

    var canRunReflection: Bool {
        guard canEditCurrentSession else {
            return false
        }

        guard let topic = currentSession?.topic.trimmingCharacters(in: .whitespacesAndNewlines), !topic.isEmpty else {
            return false
        }

        return !isRunningReflection
    }

    func updateReflectionModel(_ model: String) {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        state.ollamaSettings.reflectionModel = model
        saveState()
    }

    func updateEmbeddingModel(_ model: String) {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        state.ollamaSettings.embeddingModel = model
        saveState()
    }

    func updateTemperature(_ value: Double) {
        state.ollamaSettings.runtime.temperature = min(max(value, 0), 2)
        saveState()
    }

    func updateContextWindow(_ value: Int) {
        state.ollamaSettings.runtime.numContextTokens = max(512, value)
        saveState()
    }

    func updateMaxOutputTokens(_ value: Int) {
        state.ollamaSettings.runtime.maxOutputTokens = max(64, value)
        saveState()
    }

    func updateThreadCount(_ value: Int) {
        state.ollamaSettings.runtime.numThreads = max(1, value)
        saveState()
    }

    func refreshAvailableModels() {
        Task {
            await refreshAvailableModelsAsync()
        }
    }

    func updateTopic(_ topic: String) {
        guard canEditCurrentSession else {
            return
        }

        guard let sessionID = state.currentSessionId,
              let index = state.sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        state.sessions[index].topic = topic
        state.sessions[index].updatedAt = Date()
        saveState()
    }

    func startNewSession() {
        if let sessionID = activeSession?.id,
           let index = state.sessions.firstIndex(where: { $0.id == sessionID }) {
            state.sessions[index].status = .archived
            state.sessions[index].updatedAt = Date()
        }

        let now = Date()
        let session = Session(id: UUID(), topic: "", createdAt: now, updatedAt: now, status: .active)
        state.sessions.insert(session, at: 0)
        state.currentSessionId = session.id
        selectedReflectionID = nil
        saveState()
        refreshArchiveResults()
        addLog(.info, "Started new session")
    }

    func selectSession(_ session: Session) {
        state.currentSessionId = session.id
        selectedReflectionID = nil
        manualNote = ""
        saveState()
        addLog(.info, session.status == .active ? "Returned to active session" : "Opened archived session")
    }

    func returnToActiveSession() {
        guard let activeSession else { return }
        selectSession(activeSession)
    }

    func captureClipboardNow() {
        guard canEditCurrentSession else { return }
        processClipboardText(NSPasteboard.general.string(forType: .string) ?? "", sourceType: .clipboard, originatedFromWatcher: false)
    }

    func storeManualNote() {
        guard canEditCurrentSession else { return }
        let trimmed = manualNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addArtifact(trimmed, sourceType: .manual)
        manualNote = ""
        addLog(.success, "Stored manual note")
    }

    func toggleArtifactKept(_ artifact: Artifact) {
        mutateArtifact(artifact.id) { $0.kept.toggle() }
    }

    func toggleArtifactPinned(_ artifact: Artifact) {
        mutateArtifact(artifact.id) { $0.pinned.toggle() }
    }

    func deleteArtifact(_ artifact: Artifact) {
        mutateArtifact(artifact.id) { $0.deleted = true }
    }

    func toggleReflectionImportant(_ reflection: ReflectionRecord) {
        guard let index = state.reflections.firstIndex(where: { $0.id == reflection.id }) else {
            return
        }

        state.reflections[index].important.toggle()
        saveState()
        refreshArchiveResults()
    }

    func copyDisplayedReflection() {
        guard let reflection = displayedReflection else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(reflection.content, forType: .string)
        addLog(.success, "Copied reflection to clipboard")
    }

    func saveDisplayedReflection() {
        guard let reflection = displayedReflection else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "local-overthinker-\(fileSafeDate(reflection.createdAt)).md"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try buildMarkdownExport(for: reflection).write(to: url, atomically: true, encoding: .utf8)
            addLog(.success, "Saved reflection to \(url.lastPathComponent)")
        } catch {
            addLog(.error, "Failed to save reflection: \(error.localizedDescription)")
        }
    }

    func openDataFolder() {
        do {
            try FileManager.default.createDirectory(at: AppPaths.userDataDirectory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(AppPaths.userDataDirectory)
        } catch {
            addLog(.error, "Failed to open data folder: \(error.localizedDescription)")
        }
    }

    func resetLocalStore() {
        state = ReflectionEngine.buildInitialState()
        selectedReflectionID = nil
        archiveQuery = ""
        manualNote = ""
        saveState()
        refreshArchiveResults()
        addLog(.warning, "Reset local store")
    }

    func runReflection(force: Bool = false) {
        guard canEditCurrentSession else {
            jobState = .error
            jobMessage = "Archived sessions are read-only. Return to the active session to reflect again."
            return
        }

        Task {
            await performReflection(force: force)
        }
    }

    func relativeLabel(for date: Date?) -> String {
        guard let date else { return "not yet" }
        let delta = Date().timeIntervalSince(date)
        let isFuture = delta < 0
        let minutes = max(1, Int(abs(delta) / 60))
        if minutes < 60 {
            return isFuture ? "in \(minutes)m" : "\(minutes)m ago"
        }

        let hours = Int(round(Double(minutes) / 60))
        if hours < 24 {
            return isFuture ? "in \(hours)h" : "\(hours)h ago"
        }

        let days = Int(round(Double(hours) / 24))
        return isFuture ? "in \(days)d" : "\(days)d ago"
    }

    func timestampLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }

    func statusColor(for kind: LogKind) -> NSColor {
        switch kind {
        case .info:
            return .secondaryLabelColor
        case .success:
            return .systemGreen
        case .warning:
            return .systemOrange
        case .error:
            return .systemRed
        }
    }

    private func startServices() {
        do {
            try FileManager.default.createDirectory(at: AppPaths.userDataDirectory, withIntermediateDirectories: true)
        } catch {
            addLog(.error, "Failed to create data folder: \(error.localizedDescription)")
        }

        lastClipboardText = (NSPasteboard.general.string(forType: .string) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        clipboardStatus = .active

        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollClipboard()
            }
        }

        reflectionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.runScheduledReflectionIfNeeded()
            }
        }

        Task {
            await refreshOllamaStatus()
            await refreshAvailableModelsAsync()
            await refreshArchiveResultsAsync()
        }
    }

    private func pollClipboard() {
        let text = (NSPasteboard.general.string(forType: .string) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != lastClipboardText else {
            return
        }

        processClipboardText(text, sourceType: .clipboard, originatedFromWatcher: true)
    }

    private func processClipboardText(_ text: String, sourceType: ArtifactSourceType, originatedFromWatcher: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lastClipboardText = trimmed
        addArtifact(trimmed, sourceType: sourceType)
        lastBackgroundCaptureAt = Date()
        addLog(.info, originatedFromWatcher ? "Captured clipboard artifact" : "Captured clipboard now")
    }

    private func addArtifact(_ content: String, sourceType: ArtifactSourceType) {
        guard let sessionID = currentSession?.id else { return }

        let artifact = Artifact(
            id: UUID(),
            sessionId: sessionID,
            content: content,
            createdAt: Date(),
            sourceType: sourceType,
            pinned: false,
            kept: false,
            deleted: false,
            embeddingId: nil
        )

        state.artifacts.insert(artifact, at: 0)
        saveState()

        Task {
            _ = await ensureEmbedding(forArtifactID: artifact.id)
            await refreshArchiveResultsAsync()
        }
    }

    private func mutateArtifact(_ artifactID: UUID, mutate: (inout Artifact) -> Void) {
        guard let index = state.artifacts.firstIndex(where: { $0.id == artifactID }) else {
            return
        }

        mutate(&state.artifacts[index])
        saveState()
        refreshArchiveResults()
    }

    private func refreshArchiveResults() {
        let reflections = state.reflections.sorted { $0.createdAt > $1.createdAt }
        guard !archiveQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            archiveResults = reflections
            return
        }

        let lexical = ReflectionEngine.rankReflectionsLexically(reflections, query: archiveQuery, limit: 24)
        archiveResults = lexical.isEmpty ? reflections : lexical
    }

    private func refreshArchiveResultsAsync() async {
        refreshArchiveResults()

        let query = archiveQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, ollamaStatus == .online else { return }

        do {
            let vector = try await client.embedText(query)
            let ranked = ReflectionEngine.rankReflectionsByVectors(
                state.reflections,
                embeddings: state.embeddings,
                queryVectors: [vector],
                limit: 24
            )

            if !ranked.isEmpty {
                archiveResults = ranked
            }
        } catch {
            addLog(.warning, "Semantic archive search unavailable")
        }
    }

    private func refreshOllamaStatus() async {
        ollamaStatus = .checking
        ollamaStatus = await client.checkHealth() ? .online : .offline
    }

    private func refreshAvailableModelsAsync() async {
        guard ollamaStatus == .online else {
            availableOllamaModels = fallbackModelList()
            return
        }

        do {
            let models = try await client.listModels()
            availableOllamaModels = mergedModelList(with: models)
        } catch {
            availableOllamaModels = fallbackModelList()
            addLog(.warning, "Failed to refresh Ollama model list")
        }
    }

    private func runScheduledReflectionIfNeeded() async {
        guard canEditCurrentSession else { return }
        guard hasPendingClipboardActivityForAutomaticReflection() else {
            if jobState == .idle {
                jobMessage = "Quietly waiting for new clipboard activity."
            }
            return
        }

        let now = Date()
        if let lastRun = state.lastReflectionRunAt {
            guard now.timeIntervalSince(lastRun) >= Self.reflectionWindow else { return }
        } else if let pendingDate = latestPendingClipboardCaptureDate {
            guard now.timeIntervalSince(pendingDate) >= Self.reflectionWindow else { return }
        }

        await performReflection(force: false)
    }

    private func performReflection(force: Bool) async {
        if isRunningReflection {
            queuedReflection = true
            jobMessage = "A fresher reflection is queued after the current run."
            return
        }

        guard let session = currentSession else { return }
        let topic = session.topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty else {
            jobState = .error
            jobMessage = "Set a current topic before running a reflection."
            return
        }

        isRunningReflection = true
        jobState = .running
        jobMessage = "Building reflection context."

        defer {
            isRunningReflection = false
            if queuedReflection {
                queuedReflection = false
                Task { await performReflection(force: true) }
            }
        }

        await refreshOllamaStatus()

        let now = Date()
        let recentArtifacts = currentArtifacts.filter { now.timeIntervalSince($0.createdAt) <= Self.reflectionWindow }
        let pinnedArtifacts = currentArtifacts.filter(\.pinned)
        let previousReflections = Array(currentReflections.prefix(2))

        var retrievedArtifacts: [Artifact] = []
        var retrievedReflections: [ReflectionRecord] = []

        if ollamaStatus == .online {
            do {
                let queryVectors = try await gatherQueryVectors(topic: topic, recentArtifacts: recentArtifacts, previousReflections: previousReflections)
                let olderArtifacts = currentArtifacts.filter { now.timeIntervalSince($0.createdAt) > Self.reflectionWindow }
                let olderReflections = currentReflections.dropFirst().map { $0 }
                retrievedArtifacts = ReflectionEngine.rankArtifactsByVectors(olderArtifacts, embeddings: state.embeddings, queryVectors: queryVectors, limit: 6)
                retrievedReflections = ReflectionEngine.rankReflectionsByVectors(olderReflections, embeddings: state.embeddings, queryVectors: queryVectors, limit: 4)
            } catch {
                addLog(.warning, "Semantic retrieval fell back to local-only context")
            }
        }

        let inputs = ReflectionInputs(
            currentTopic: topic,
            recentArtifacts: recentArtifacts,
            pinnedArtifacts: pinnedArtifacts,
            retrievedArtifacts: retrievedArtifacts,
            retrievedReflections: retrievedReflections,
            previousReflections: previousReflections,
            longTermUserContext: state.userContext.content
        )

        let content: String
        if ollamaStatus == .online {
            do {
                jobMessage = "Generating reflection with \(client.settings.reflectionModel)."
                content = try await client.generateReflection(
                    system: systemPrompt,
                    user: ReflectionEngine.buildPrompt(from: inputs)
                )
            } catch {
                addLog(.warning, "Model reflection failed, using fallback synthesis")
                content = ReflectionEngine.buildFallbackReflection(from: inputs)
            }
        } else {
            content = ReflectionEngine.buildFallbackReflection(from: inputs)
        }

        let tags = ReflectionEngine.extractTags(from: content)
        var reflection = ReflectionRecord(
            id: UUID(),
            sessionId: session.id,
            content: content,
            createdAt: now,
            model: ollamaStatus == .online ? client.settings.reflectionModel : "local-fallback",
            important: false,
            tags: tags,
            embeddingId: nil
        )

        state.reflections.insert(reflection, at: 0)
        state.lastReflectionRunAt = now
        selectedReflectionID = reflection.id
        saveState()

        if ollamaStatus == .online {
            reflection.embeddingId = await ensureEmbedding(for: content, entityType: .reflection, entityID: reflection.id, existingEmbeddingID: reflection.embeddingId)
            if let index = state.reflections.firstIndex(where: { $0.id == reflection.id }) {
                state.reflections[index] = reflection
                saveState()
            }
        }

        jobState = .idle
        jobMessage = force ? "Reflection regenerated." : "Latest reflection is ready."
        refreshArchiveResults()
        addLog(.success, "Generated reflection")
    }

    private var latestPendingClipboardCaptureDate: Date? {
        let lastRun = state.lastReflectionRunAt
        return currentArtifacts
            .filter { $0.sourceType == .clipboard }
            .map(\.createdAt)
            .filter { date in
                if let lastRun {
                    return date > lastRun
                }

                return true
            }
            .max()
    }

    private func hasPendingClipboardActivityForAutomaticReflection() -> Bool {
        latestPendingClipboardCaptureDate != nil
    }

    private func fallbackModelList() -> [String] {
        mergedModelList(with: [])
    }

    private func mergedModelList(with models: [String]) -> [String] {
        Array(
            Set(models + [state.ollamaSettings.reflectionModel, state.ollamaSettings.embeddingModel])
        )
        .sorted()
    }

    private func gatherQueryVectors(topic: String, recentArtifacts: [Artifact], previousReflections: [ReflectionRecord]) async throws -> [[Double]] {
        var vectors: [[Double]] = []

        if let topicVector = await ensureEmbedding(for: topic, entityType: .topic, entityID: currentSession?.id ?? UUID(), existingEmbeddingID: currentSessionEmbeddingID()) {
            if let vector = state.embeddings.first(where: { $0.id == topicVector })?.vector {
                vectors.append(vector)
            }
        }

        for artifact in recentArtifacts.prefix(4) {
            let embeddingID = await ensureEmbedding(forArtifactID: artifact.id)
            if let embeddingID,
               let vector = state.embeddings.first(where: { $0.id == embeddingID })?.vector {
                vectors.append(vector)
            }
        }

        if let previous = previousReflections.first {
            let embeddingID = await ensureEmbedding(for: previous.content, entityType: .reflection, entityID: previous.id, existingEmbeddingID: previous.embeddingId)
            if let embeddingID,
               let vector = state.embeddings.first(where: { $0.id == embeddingID })?.vector {
                vectors.append(vector)
            }
        }

        return vectors
    }

    private func currentSessionEmbeddingID() -> UUID? {
        guard let session = currentSession else { return nil }
        return state.embeddings.first(where: { $0.entityType == .topic && $0.entityId == session.id })?.id
    }

    private func ensureEmbedding(forArtifactID artifactID: UUID) async -> UUID? {
        guard let artifactIndex = state.artifacts.firstIndex(where: { $0.id == artifactID }) else {
            return nil
        }

        let artifact = state.artifacts[artifactIndex]
        let embeddingID = await ensureEmbedding(for: artifact.content, entityType: .artifact, entityID: artifact.id, existingEmbeddingID: artifact.embeddingId)
        if let embeddingID {
            state.artifacts[artifactIndex].embeddingId = embeddingID
            saveState()
        }
        return embeddingID
    }

    private func ensureEmbedding(for text: String, entityType: EmbeddingEntityType, entityID: UUID, existingEmbeddingID: UUID?) async -> UUID? {
        guard ollamaStatus == .online, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return existingEmbeddingID
        }

        if let existingEmbeddingID,
           state.embeddings.contains(where: { $0.id == existingEmbeddingID }) {
            return existingEmbeddingID
        }

        do {
            let vector = try await client.embedText(text)
            let embeddingID = existingEmbeddingID ?? UUID()
            state.embeddings.removeAll { $0.id == embeddingID }
            state.embeddings.append(
                EmbeddingRecord(
                    id: embeddingID,
                    entityType: entityType,
                    entityId: entityID,
                    vector: vector,
                    createdAt: Date()
                )
            )
            saveState()
            return embeddingID
        } catch {
            addLog(.warning, "Embedding unavailable for \(entityType.rawValue)")
            return existingEmbeddingID
        }
    }

    private func buildMarkdownExport(for reflection: ReflectionRecord) -> String {
        let tags = Array(Set(reflection.tags.filter { !$0.isEmpty })).sorted()
        let topic = currentSession?.topic ?? "Local Overthinker Reflection"
        let dateFormatter = ISO8601DateFormatter()

        let yamlTags = tags.isEmpty ? ["reflection"] : tags
        let tagLines = yamlTags.map { "  - \"\(escapeYAML($0))\"" }.joined(separator: "\n")

        return """
        ---
        created: "\(dateFormatter.string(from: reflection.createdAt))"
        topic: "\(escapeYAML(topic))"
        tags:
        \(tagLines)
        ---

        \(reflection.content)
        """
    }

    private func saveState() {
        guard persistenceEnabled else {
            return
        }

        do {
            let data = try encoder.encode(state)
            try data.write(to: AppPaths.stateFileURL, options: .atomic)
        } catch {
            addLog(.error, "Failed to save state: \(error.localizedDescription)")
        }
    }

    private func addLog(_ kind: LogKind, _ message: String) {
        logEntries.append(LogEntry(timestamp: Date(), kind: kind, message: message))
        if logEntries.count > 200 {
            logEntries.removeFirst(logEntries.count - 200)
        }
    }

    private func escapeYAML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func fileSafeDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }
}
