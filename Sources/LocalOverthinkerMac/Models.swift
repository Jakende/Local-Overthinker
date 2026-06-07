import Foundation

enum SessionStatus: String, Codable {
    case active
    case archived
}

enum ArtifactSourceType: String, Codable {
    case clipboard
    case manual
}

enum EmbeddingEntityType: String, Codable {
    case artifact
    case reflection
    case topic
    case context
    case search
}

enum JobState {
    case idle
    case running
    case error
}

enum OllamaStatus {
    case checking
    case online
    case offline
}

enum LogKind {
    case info
    case success
    case warning
    case error
}

struct Session: Identifiable, Codable, Hashable {
    let id: UUID
    var topic: String
    var createdAt: Date
    var updatedAt: Date
    var status: SessionStatus
}

struct Artifact: Identifiable, Codable, Hashable {
    let id: UUID
    let sessionId: UUID
    var content: String
    var createdAt: Date
    var sourceType: ArtifactSourceType
    var pinned: Bool
    var kept: Bool
    var deleted: Bool
    var embeddingId: UUID?
}

struct ReflectionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let sessionId: UUID
    var content: String
    var createdAt: Date
    var model: String
    var important: Bool
    var tags: [String]
    var embeddingId: UUID?
}

struct UserContextRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var content: String
    var active: Bool
    var updatedAt: Date
    var embeddingId: UUID?
}

struct EmbeddingRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let entityType: EmbeddingEntityType
    let entityId: UUID
    var vector: [Double]
    var createdAt: Date
}

struct AppState: Codable {
    var sessions: [Session]
    var artifacts: [Artifact]
    var reflections: [ReflectionRecord]
    var userContext: UserContextRecord
    var embeddings: [EmbeddingRecord]
    var currentSessionId: UUID?
    var lastReflectionRunAt: Date?
    var ollamaSettings: OllamaSettings

    init(
        sessions: [Session],
        artifacts: [Artifact],
        reflections: [ReflectionRecord],
        userContext: UserContextRecord,
        embeddings: [EmbeddingRecord],
        currentSessionId: UUID?,
        lastReflectionRunAt: Date?,
        ollamaSettings: OllamaSettings = .default
    ) {
        self.sessions = sessions
        self.artifacts = artifacts
        self.reflections = reflections
        self.userContext = userContext
        self.embeddings = embeddings
        self.currentSessionId = currentSessionId
        self.lastReflectionRunAt = lastReflectionRunAt
        self.ollamaSettings = ollamaSettings
    }

    private enum CodingKeys: String, CodingKey {
        case sessions
        case artifacts
        case reflections
        case userContext
        case embeddings
        case currentSessionId
        case lastReflectionRunAt
        case ollamaSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessions = try container.decode([Session].self, forKey: .sessions)
        artifacts = try container.decode([Artifact].self, forKey: .artifacts)
        reflections = try container.decode([ReflectionRecord].self, forKey: .reflections)
        userContext = try container.decode(UserContextRecord.self, forKey: .userContext)
        embeddings = try container.decode([EmbeddingRecord].self, forKey: .embeddings)
        currentSessionId = try container.decodeIfPresent(UUID.self, forKey: .currentSessionId)
        lastReflectionRunAt = try container.decodeIfPresent(Date.self, forKey: .lastReflectionRunAt)
        ollamaSettings = try container.decodeIfPresent(OllamaSettings.self, forKey: .ollamaSettings) ?? .default
    }
}

struct ReflectionInputs {
    var currentTopic: String
    var recentArtifacts: [Artifact]
    var pinnedArtifacts: [Artifact]
    var retrievedArtifacts: [Artifact]
    var retrievedReflections: [ReflectionRecord]
    var previousReflections: [ReflectionRecord]
    var longTermUserContext: String
}

struct ReflectionSection: Identifiable, Hashable {
    let id = UUID()
    let heading: String
    let body: String
}

struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let timestamp: Date
    let kind: LogKind
    let message: String
}

struct OllamaRuntimeOptions: Codable, Hashable {
    var temperature: Double
    var numContextTokens: Int
    var maxOutputTokens: Int
    var numThreads: Int
    var keepAlive: String

    static let `default` = OllamaRuntimeOptions(
        temperature: 0.2,
        numContextTokens: 2048,
        maxOutputTokens: 320,
        numThreads: 2,
        keepAlive: "0m"
    )
}

struct OllamaSettings: Codable, Hashable {
    var baseURL: URL
    var reflectionModel: String
    var embeddingModel: String
    var runtime: OllamaRuntimeOptions

    static let `default` = OllamaSettings(
        baseURL: URL(string: "http://127.0.0.1:11434")!,
        reflectionModel: "qwen3:0.6b",
        embeddingModel: "nomic-embed-text",
        runtime: .default
    )
}

enum ClipboardSourceStatus {
    case active
    case inactive
}
