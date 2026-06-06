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

struct OllamaSettings {
    var baseURL: URL
    var reflectionModel: String
    var embeddingModel: String

    static let `default` = OllamaSettings(
        baseURL: URL(string: "http://127.0.0.1:11434")!,
        reflectionModel: "qwen3:0.6b",
        embeddingModel: "nomic-embed-text"
    )
}

enum ClipboardSourceStatus {
    case active
    case inactive
}
