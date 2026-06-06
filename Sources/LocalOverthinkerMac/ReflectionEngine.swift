import Foundation

enum ReflectionEngine {
    private static let maxItemCharacters = 480
    private static let maxContextCharacters = 1600

    static let defaultUserContext = """
    Jakob Endemann is a landscape architecture and landscape planning student at the Technical University of Munich. He works between spatial planning, professional politics, student representation, institutional reform, curriculum design, democratic culture, New Work, AI-supported analysis, GIS, and transdisciplinary knowledge production.

    He thinks structurally and is interested in mechanisms: how chambers, universities, offices, accreditation systems, professional titles, labor cultures, informal networks, and student institutions shape the future of planning disciplines.

    He is critically analyzing the Architektenkammer system, especially the relationship between chamber membership, protected titles, building permit authority, status, competence, and professional gatekeeping.

    He observes a gap between university education and vocational readiness. He is interested in bridging this through curriculum reform, activist institutional work, documentation structures, and better knowledge transfer.

    He critiques self-exploitation in architecture, landscape architecture, and planning cultures. He rejects the romanticized myth of the starving architect or planner and is interested in integrating labor rights, professional longevity, and Future Work concepts into education and professional institutions.

    He approaches activism systemically. Climate protection, democratic culture, fair work, and professional sustainability should be built into institutions rather than depending on individual sacrifice.
    """

    static let bundledSystemPrompt = """
    You are Local Overthinker, a private, locally running reflective reasoning assistant.

    You receive a current topic, recent copied or written artifacts, pinned artifacts, retrieved older material, previous reflections, and long-term user context.

    Generate one structured reflection. Do not ask the user questions interactively. Do not merely summarize. Identify implications, hidden assumptions, tensions, larger structures, and useful next steps. If the material is fragmented, work cautiously from what is available.

    Always use this structure:

    # Reflection

    ## Core Thought

    ## What Is Emerging

    ## Hidden Assumptions

    ## Tensions

    ## Systemic Reading

    ## Connection to Long-Term Context

    ## Next Useful Thoughts

    ## Reusable Sentence

    ## Tags
    """

    static func loadSystemPrompt() -> String {
        if let bundledURL = Bundle.main.url(forResource: "Systemprompt", withExtension: "md"),
           let prompt = try? String(contentsOf: bundledURL, encoding: .utf8),
           !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return prompt
        }

        let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let candidates = [
            currentDirectory.appendingPathComponent("Systemprompt.md"),
            currentDirectory.appendingPathComponent("../Systemprompt.md"),
            URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("Systemprompt.md"),
            URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("../Systemprompt.md")
        ]

        for candidate in candidates {
            if let prompt = try? String(contentsOf: candidate, encoding: .utf8), !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return prompt
            }
        }

        return bundledSystemPrompt
    }

    static func buildInitialState() -> AppState {
        let now = Date()
        let sessionID = UUID()

        return AppState(
            sessions: [
                Session(
                    id: sessionID,
                    topic: "I am working on the professional self-understanding of planning disciplines and the future role of chambers, universities, and young planners.",
                    createdAt: now,
                    updatedAt: now,
                    status: .active
                )
            ],
            artifacts: [],
            reflections: [],
            userContext: UserContextRecord(
                id: UUID(),
                content: defaultUserContext,
                active: true,
                updatedAt: now,
                embeddingId: nil
            ),
            embeddings: [],
            currentSessionId: sessionID,
            lastReflectionRunAt: nil
        )
    }

    static func buildPreviewState() -> AppState {
        let now = Date()
        let sessionID = UUID()

        let artifacts = [
            Artifact(
                id: UUID(),
                sessionId: sessionID,
                content: "The chamber question is not only about access to protected titles, but about who is allowed to define competence and professional legitimacy in planning.",
                createdAt: now.addingTimeInterval(-5400),
                sourceType: .clipboard,
                pinned: true,
                kept: true,
                deleted: false,
                embeddingId: nil
            ),
            Artifact(
                id: UUID(),
                sessionId: sessionID,
                content: "Universities teach conceptual breadth, but offices and chambers often reward procedural readiness and immediate permit-related utility.",
                createdAt: now.addingTimeInterval(-4200),
                sourceType: .clipboard,
                pinned: false,
                kept: true,
                deleted: false,
                embeddingId: nil
            ),
            Artifact(
                id: UUID(),
                sessionId: sessionID,
                content: "Young planners may need representation that is not symbolic but structurally connected to curriculum, labor conditions, and institutional reform.",
                createdAt: now.addingTimeInterval(-1800),
                sourceType: .manual,
                pinned: false,
                kept: false,
                deleted: false,
                embeddingId: nil
            )
        ]

        let reflectionContent = """
        # Reflection

        ## Core Thought

        The recent material is not only about professional identity in the abstract. It is circling around the institutional distribution of legitimacy: who defines readiness, who confers status, and how that affects the future role of planning disciplines.

        ## What Is Emerging

        - Chamber legitimacy is being treated as a design question, not a fixed professional fact.
        - University education and office readiness appear as structurally misaligned rather than merely sequential.
        - Student and early-career representation is becoming a governance problem, not only a communication problem.

        ## Hidden Assumptions

        - Professional authority is assumed to be reformable through institutions rather than only defended rhetorically.
        - Curriculum reform is being treated as a lever for labor culture and long-term disciplinary survival.

        ## Tensions

        - Critical distance from chambers conflicts with the wish to use them as reform platforms.
        - Broad disciplinary language conflicts with the need for precise institutional mechanisms.

        ## Systemic Reading

        The larger mechanism here is the coupling of education, credentialing, and gatekeeping. Chambers, universities, and offices do not simply prepare planners; they sort, authorize, and stabilize what counts as legitimate professional practice.

        ## Connection to Long-Term Context

        This sits directly inside Jakob's recurring work on chamber reform, curriculum design, anti-exploitation, and the relationship between planning culture and institutional structure.

        ## Next Useful Thoughts

        - Separate the question of title protection from the question of actual competence.
        - Define what kind of institutional representation young planners would need to influence curriculum and labor conditions.
        - Clarify whether the main argument is about legitimacy, readiness, or governance.

        ## Reusable Sentence

        The future role of planning disciplines depends less on symbolic identity claims than on how institutions distribute legitimacy, readiness, and room for practice.

        ## Tags

        chamber reform, curriculum, legitimacy, planning culture, professional identity, young planners
        """

        let reflection = ReflectionRecord(
            id: UUID(),
            sessionId: sessionID,
            content: reflectionContent,
            createdAt: now.addingTimeInterval(-900),
            model: OllamaSettings.default.reflectionModel,
            important: true,
            tags: ["chamber reform", "curriculum", "legitimacy", "planning culture", "professional identity", "young planners"],
            embeddingId: nil
        )

        return AppState(
            sessions: [
                Session(
                    id: sessionID,
                    topic: "I am working on the professional self-understanding of planning disciplines and the future role of chambers, universities, and young planners.",
                    createdAt: now.addingTimeInterval(-7200),
                    updatedAt: now.addingTimeInterval(-300),
                    status: .active
                )
            ],
            artifacts: artifacts,
            reflections: [reflection],
            userContext: UserContextRecord(
                id: UUID(),
                content: defaultUserContext,
                active: true,
                updatedAt: now.addingTimeInterval(-7200),
                embeddingId: nil
            ),
            embeddings: [],
            currentSessionId: sessionID,
            lastReflectionRunAt: now.addingTimeInterval(-900)
        )
    }

    static func buildPrompt(from inputs: ReflectionInputs) -> String {
        let semanticMemory = (inputs.retrievedArtifacts.map(formatArtifact) + inputs.retrievedReflections.map(formatReflection))
            .joined(separator: "\n")

        return """
        CURRENT_TOPIC:
        \(inputs.currentTopic.isEmpty ? "(none)" : inputs.currentTopic)

        RECENT_ARTIFACTS:
        \(inputs.recentArtifacts.isEmpty ? "(none)" : inputs.recentArtifacts.map(formatArtifact).joined(separator: "\n"))

        PINNED_ARTIFACTS:
        \(inputs.pinnedArtifacts.isEmpty ? "(none)" : inputs.pinnedArtifacts.map(formatArtifact).joined(separator: "\n"))

        SEMANTICALLY_RETRIEVED_MEMORY:
        \(semanticMemory.isEmpty ? "(none)" : semanticMemory)

        PREVIOUS_REFLECTIONS:
        \(inputs.previousReflections.isEmpty ? "(none)" : inputs.previousReflections.map(formatReflection).joined(separator: "\n"))

        LONG_TERM_USER_CONTEXT:
        \(inputs.longTermUserContext.isEmpty ? "(none)" : clipText(inputs.longTermUserContext, limit: maxContextCharacters))
        """
    }

    static func buildFallbackReflection(from inputs: ReflectionInputs) -> String {
        let recentCombined = inputs.recentArtifacts.map(\.content).joined(separator: " ")
        let pinnedCombined = inputs.pinnedArtifacts.map(\.content).joined(separator: " ")
        let retrievedCombined = inputs.retrievedArtifacts.map(\.content).joined(separator: " ")
        let previousReflection = inputs.previousReflections.first?.content ?? ""
        let tags = deriveTags(topic: inputs.currentTopic, artifacts: inputs.recentArtifacts)

        let coreThought: String
        if inputs.recentArtifacts.isEmpty {
            coreThought = "There is little new material in the current window, so the useful task is continuity rather than expansion."
        } else {
            coreThought = sliceSentences(
                from: "\(recentCombined) \(pinnedCombined)",
                fallback: "The recent material points toward an emerging line of argument rather than a finished position.",
                limit: 2
            )
        }

        let emerging = inputs.recentArtifacts.isEmpty
            ? [
                "The session appears to be between collection and synthesis.",
                "The archive may already contain material that needs re-reading more than more capture."
            ]
            : [
                "The topic is being worked through by collecting fragments rather than drafting a finished argument.",
                "The material suggests a search for institutional language that can connect education, professional identity, and reform.",
                retrievedCombined.isEmpty
                    ? "The immediate archive still outweighs older memory, so continuity remains provisional."
                    : "Older semantically related material appears close enough to indicate continuity rather than a completely new direction."
            ]

        let hiddenAssumptions = [
            "A stronger professional role is being treated as something institutions can design rather than something that emerges automatically.",
            "Educational reform is assumed to matter for professional culture, not only for course administration.",
            pinnedCombined.isEmpty
                ? "Without pinned fragments, importance is still being inferred from recency rather than deliberate emphasis."
                : "Pinned fragments imply that some details are already being treated as anchors for later argument."
        ]

        let tensions = [
            "There is a tension between critical distance from institutions and the wish to reform them from within.",
            "There is a tension between broad disciplinary framing and the need for precise institutional mechanisms.",
            previousReflection.isEmpty
                ? "Without a previous reflection, the current material risks remaining a collection layer rather than an argumentative layer."
                : "The previous reflection suggests continuity, but the current material may still be circling the same unresolved distinction."
        ]

        let systemicReading = sliceSentences(
            from: "\(inputs.currentTopic) \(retrievedCombined) \(previousReflection)",
            fallback: "The central mechanism appears to be the way institutions distribute legitimacy, readiness, and professional status.",
            limit: 3
        )

        let connection = sliceSentences(
            from: "\(inputs.currentTopic) \(inputs.longTermUserContext)",
            fallback: "This remains consistent with Jakob's long-term interest in institutional reform, planning culture, and the translation between education and practice.",
            limit: 2
        )

        let nextThoughts = [
            "Clarify which institutional mechanism is actually under analysis: title protection, chamber membership, curriculum design, or labor culture.",
            "Separate descriptive observations from reform claims so the argument does not blur diagnosis and proposal.",
            "Identify one sentence that explains why young planners are structurally affected rather than merely symbolically represented."
        ]

        let reusableSentence = "The material suggests that the future role of planning disciplines will depend less on abstract identity claims than on how institutions distribute legitimacy, readiness, and room for practice."

        return """
        # Reflection

        ## Core Thought

        \(coreThought)

        ## What Is Emerging

        \(emerging.map { "- \($0)" }.joined(separator: "\n"))

        ## Hidden Assumptions

        \(hiddenAssumptions.map { "- \($0)" }.joined(separator: "\n"))

        ## Tensions

        \(tensions.map { "- \($0)" }.joined(separator: "\n"))

        ## Systemic Reading

        \(systemicReading)

        ## Connection to Long-Term Context

        \(connection)

        ## Next Useful Thoughts

        \(nextThoughts.map { "- \($0)" }.joined(separator: "\n"))

        ## Reusable Sentence

        \(reusableSentence)

        ## Tags

        \((tags.isEmpty ? ["planning", "institutions", "continuity", "archive", "reflection"] : tags).joined(separator: ", "))
        """
    }

    static func extractTags(from content: String) -> [String] {
        guard let range = content.range(of: #"## Tags\s+([\s\S]*)$"#, options: .regularExpression) else {
            return []
        }

        let tagBlock = String(content[range]).replacingOccurrences(of: "## Tags", with: "")
        let rawTags = tagBlock.split(whereSeparator: { $0 == "\n" || $0 == "," })
        let cleanedTags = rawTags
            .map { String($0).replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(cleanedTags.prefix(8))
    }

    static func parseSections(from content: String) -> [ReflectionSection] {
        let normalized = content.replacingOccurrences(of: #"^# Reflection\s*"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        let blocks = normalized.components(separatedBy: "\n## ").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return blocks.compactMap { block in
            let cleaned = block.hasPrefix("## ") ? String(block.dropFirst(3)) : block
            let lines = cleaned.components(separatedBy: .newlines)
            guard let heading = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines), !heading.isEmpty else {
                return nil
            }

            return ReflectionSection(
                heading: heading,
                body: lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    static func rankReflectionsLexically(_ reflections: [ReflectionRecord], query: String, limit: Int) -> [ReflectionRecord] {
        reflections
            .map { reflection in
                (reflection, lexicalScore(text: "\(reflection.content)\n\(reflection.tags.joined(separator: " "))", query: query))
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    static func rankArtifactsByVectors(_ artifacts: [Artifact], embeddings: [EmbeddingRecord], queryVectors: [[Double]], limit: Int) -> [Artifact] {
        rankByVectors(artifacts, embeddings: embeddings, entityType: .artifact, queryVectors: queryVectors, limit: limit)
    }

    static func rankReflectionsByVectors(_ reflections: [ReflectionRecord], embeddings: [EmbeddingRecord], queryVectors: [[Double]], limit: Int) -> [ReflectionRecord] {
        rankByVectors(reflections, embeddings: embeddings, entityType: .reflection, queryVectors: queryVectors, limit: limit)
    }

    static func cosineSimilarity(_ left: [Double], _ right: [Double]) -> Double {
        guard !left.isEmpty, left.count == right.count else {
            return 0
        }

        var dot = 0.0
        var leftNorm = 0.0
        var rightNorm = 0.0

        for index in left.indices {
            dot += left[index] * right[index]
            leftNorm += left[index] * left[index]
            rightNorm += right[index] * right[index]
        }

        guard leftNorm > 0, rightNorm > 0 else {
            return 0
        }

        return dot / (sqrt(leftNorm) * sqrt(rightNorm))
    }

    private static func rankByVectors<T: Identifiable>(_ items: [T], embeddings: [EmbeddingRecord], entityType: EmbeddingEntityType, queryVectors: [[Double]], limit: Int) -> [T] where T.ID == UUID {
        var scored: [(T, Double)] = []

        for item in items {
            guard let vector = embeddingVector(for: item.id, entityType: entityType, in: embeddings) else {
                continue
            }

            let score = queryVectors.map { cosineSimilarity(vector, $0) }.max() ?? -1
            scored.append((item, score))
        }

        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    private static func embeddingVector(for entityID: UUID, entityType: EmbeddingEntityType, in embeddings: [EmbeddingRecord]) -> [Double]? {
        for embedding in embeddings where embedding.entityType == entityType && embedding.entityId == entityID {
            return embedding.vector
        }

        return nil
    }

    private static func lexicalScore(text: String, query: String) -> Int {
        let normalizedText = text.lowercased()
        let terms = query.lowercased().split(separator: " ").filter { $0.count > 1 }
        return terms.reduce(into: 0) { score, term in
            if normalizedText.contains(term) {
                score += 1
            }
        }
    }

    private static func deriveTags(topic: String, artifacts: [Artifact]) -> [String] {
        let combined = "\(topic) \(artifacts.map(\.content).joined(separator: " "))"
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s-]"#, with: " ", options: .regularExpression)

        var counts: [String: Int] = [:]
        for word in combined.split(separator: " ").map(String.init) where word.count > 4 {
            counts[word, default: 0] += 1
        }

        return counts
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map(\.key)
    }

    private static func clipText(_ text: String, limit: Int) -> String {
        let normalized = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > limit else {
            return normalized
        }

        return String(normalized.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    private static func formatArtifact(_ artifact: Artifact) -> String {
        "- [\(artifact.sourceType.rawValue)] \(clipText(artifact.content, limit: maxItemCharacters))"
    }

    private static func formatReflection(_ reflection: ReflectionRecord) -> String {
        "- \(clipText(reflection.content, limit: maxItemCharacters))"
    }

    private static func sliceSentences(from text: String, fallback: String, limit: Int) -> String {
        let sentences = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .split(separator: ".")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(limit)
            .map { $0.hasSuffix(".") ? $0 : "\($0)." }

        return sentences.isEmpty ? fallback : sentences.joined(separator: " ")
    }
}
