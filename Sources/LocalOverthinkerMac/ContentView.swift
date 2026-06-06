import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Button("Capture Now") {
                    store.captureClipboardNow()
                }
                .buttonStyle(.bordered)

                Button("Start New Session") {
                    store.startNewSession()
                }
                .buttonStyle(.bordered)
                .disabled(store.jobState == .running)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Current Topic")
                    .font(.headline)

                TextField(
                    "What are you working on?",
                    text: Binding(
                        get: { store.currentSession?.topic ?? "" },
                        set: { store.updateTopic($0) }
                    ),
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .disabled(!store.canEditCurrentSession)

                Text("Copied fragments appear automatically. Manual notes remain optional.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Session History")
                        .font(.headline)

                    Spacer()

                    if store.isViewingArchivedSession {
                        Button("Back to Active") {
                            store.returnToActiveSession()
                        }
                        .font(.caption)
                    }
                }

                List(store.sessionHistory, selection: Binding(
                    get: { store.currentSession?.id },
                    set: { newValue in
                        guard let newValue,
                              let session = store.sessionHistory.first(where: { $0.id == newValue }) else {
                            return
                        }
                        store.selectSession(session)
                    }
                )) { session in
                    SessionRow(
                        session: session,
                        isSelected: session.id == store.currentSession?.id,
                        timestampLabel: store.timestampLabel(for: session.updatedAt)
                    )
                }
                .frame(minHeight: 132, maxHeight: 180)
                .listStyle(.sidebar)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Manual Note")
                    .font(.headline)

                TextEditor(text: $store.manualNote)
                    .font(.body)
                    .frame(minHeight: 86)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.separator, lineWidth: 1)
                    )
                    .disabled(!store.canEditCurrentSession)

                HStack {
                    Text("\(store.currentArtifacts.count) memory items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Store Note") {
                        store.storeManualNote()
                    }
                    .disabled(store.manualNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.canEditCurrentSession)
                }
            }

            if store.currentArtifacts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text("No recent memory")
                        .font(.headline)
                    Text("Copy in any app or add one short note.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.currentArtifacts) { artifact in
                        ArtifactRow(artifact: artifact)
                            .environmentObject(store)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .padding()
        .navigationTitle("Inputs")
        .navigationSplitViewColumnWidth(min: 300, ideal: 340)
    }

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                settingsPanel
                runBar
                reflectionPanel
                archivePanel
                activityPanel
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Local Overthinker")
                .font(.title2.bold())
            Text("Quiet local reflections over clipboard fragments, notes, and semantically related memory.")
                .foregroundStyle(.secondary)
            if let session = store.currentSession {
                Text(session.status == .active ? "Active session" : "Session history view")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var settingsPanel: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 14) {
            GridRow {
                Text("Models")
                Text("\(storeModelName) + \(embeddingModelName)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            GridRow {
                Text("Ollama")
                Text(ollamaStatusLabel)
                    .foregroundStyle(ollamaStatusColor)
            }

            GridRow {
                Text("Clipboard")
                Text(store.clipboardStatus == .active ? "Background watcher active" : "Watcher unavailable")
                    .foregroundStyle(.secondary)
            }

            GridRow {
                Text("Last Run")
                Text(store.relativeLabel(for: store.state.lastReflectionRunAt))
                    .foregroundStyle(.secondary)
            }

            GridRow {
                Text("Next Window")
                Text(store.nextReflectionDate.map(store.relativeLabel(for:)) ?? "now")
                    .foregroundStyle(.secondary)
            }

            GridRow {
                Text("Data")
                HStack(spacing: 8) {
                    Text(AppPaths.userDataDirectory.lastPathComponent)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button("Open") {
                        store.openDataFolder()
                    }
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var runBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(runBarTitle)
                    .font(.headline)
                Text(store.jobMessage)
                    .font(.caption)
                    .foregroundStyle(store.jobState == .running ? .primary : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            if store.jobState == .running {
                ProgressView()
                    .controlSize(.small)
            }

            Button(store.jobState == .running ? "Running..." : "Regenerate") {
                store.runReflection(force: true)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canRunReflection)
        }
    }

    private var reflectionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Latest Reflection")
                        .font(.headline)
                    if let reflection = store.displayedReflection {
                        Text(store.timestampLabel(for: reflection.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("Copy") {
                        store.copyDisplayedReflection()
                    }
                    .disabled(store.displayedReflection == nil)

                    Button("Save") {
                        store.saveDisplayedReflection()
                    }
                    .disabled(store.displayedReflection == nil)

                    Button("Mark Important") {
                        if let reflection = store.displayedReflection {
                            store.toggleReflectionImportant(reflection)
                        }
                    }
                    .disabled(store.displayedReflection == nil)
                }
            }

            if let reflection = store.displayedReflection {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(ReflectionEngine.parseSections(from: reflection.content)) { section in
                            ReflectionSectionView(section: section)
                        }
                    }
                    .padding(12)
                }
                .frame(minHeight: 260)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator, lineWidth: 1)
                )
            } else {
                EmptyUtilityState(
                    image: "text.alignleft",
                    title: "No reflection yet",
                    message: "The first reflection window or a manual run will populate this area."
                )
            }
        }
    }

    private var archivePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Archive")
                    .font(.headline)
                Spacer()
                Button("Use Latest") {
                    store.selectedReflectionID = nil
                }
                .disabled(store.latestReflection == nil)
                Button("Reset Store") {
                    store.resetLocalStore()
                }
                .disabled(store.jobState == .running)
            }

            TextField("Search reflections", text: $store.archiveQuery)
                .textFieldStyle(.roundedBorder)

            if store.archiveResults.isEmpty {
                EmptyUtilityState(
                    image: "magnifyingglass",
                    title: "No archive matches",
                    message: "Try a broader phrase or wait until more reflections accumulate."
                )
            } else {
                List(store.archiveResults, selection: $store.selectedReflectionID) { reflection in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(store.timestampLabel(for: reflection.createdAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if reflection.important {
                                Text("important")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        Text(previewText(for: reflection))
                            .lineLimit(2)
                        if !reflection.tags.isEmpty {
                            Text(reflection.tags.prefix(5).joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 3)
                }
                .frame(minHeight: 170)
            }
        }
    }

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Activity")
                    .font(.headline)
                Spacer()
                Text("Local only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ActivityLogView(entries: store.logEntries, colorForKind: store.statusColor(for:))
        }
    }

    private var storeModelName: String {
        OllamaSettings.default.reflectionModel
    }

    private var embeddingModelName: String {
        OllamaSettings.default.embeddingModel
    }

    private var ollamaStatusLabel: String {
        switch store.ollamaStatus {
        case .checking:
            return "Checking connection"
        case .online:
            return "Connected"
        case .offline:
            return "Offline, using fallback reflections"
        }
    }

    private var ollamaStatusColor: Color {
        switch store.ollamaStatus {
        case .checking:
            return .secondary
        case .online:
            return .green
        case .offline:
            return .red
        }
    }

    private var runBarTitle: String {
        if store.isViewingArchivedSession {
            return "Archived sessions are read-only"
        }

        return store.currentSession?.topic.isEmpty == false ? "Current reflection context is ready" : "Set a current topic to begin"
    }

    private func previewText(for reflection: ReflectionRecord) -> String {
        let firstSection = ReflectionEngine.parseSections(from: reflection.content).first?.body ?? reflection.content
        return firstSection.replacingOccurrences(of: "\n", with: " ")
    }
}

private struct SessionRow: View {
    let session: Session
    let isSelected: Bool
    let timestampLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(session.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled session" : session.topic)
                    .lineLimit(2)
                    .font(.body)

                Spacer(minLength: 6)

                if session.status == .active {
                    Text("active")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Text(timestampLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
    }
}

private struct ArtifactRow: View {
    let artifact: Artifact
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(artifact.content.replacingOccurrences(of: "\n", with: " "))
                    .lineLimit(2)
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    if artifact.pinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.secondary)
                    }
                    if artifact.kept {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("\(artifact.sourceType.rawValue) · \(store.timestampLabel(for: artifact.createdAt))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Button(artifact.kept ? "Unkeep" : "Keep") {
                    store.toggleArtifactKept(artifact)
                }
                Button(artifact.pinned ? "Unpin" : "Pin") {
                    store.toggleArtifactPinned(artifact)
                }
                Button("Delete") {
                    store.deleteArtifact(artifact)
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.vertical, 3)
    }
}

private struct ReflectionSectionView: View {
    let section: ReflectionSection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.heading)
                .font(.headline)

            if section.heading.lowercased() == "tags" {
                FlowTagView(tags: tags)
            } else if section.heading.lowercased() == "reusable sentence" {
                Text(section.body)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            } else if isBulletList {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(listItems, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                            Text(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .textSelection(.enabled)
            } else {
                Text(section.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var listItems: [String] {
        section.body
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: #"^[-*]\s*"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var isBulletList: Bool {
        let lines = section.body.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return !lines.isEmpty && lines.allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-") || $0.trimmingCharacters(in: .whitespaces).hasPrefix("*") }
    }

    private var tags: [String] {
        section.body
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct FlowTagView: View {
    let tags: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

private struct EmptyUtilityState: View {
    let image: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: image)
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
    }
}

private struct ActivityLogView: View {
    let entries: [LogEntry]
    let colorForKind: (LogKind) -> NSColor

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(entries) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(timeText(for: entry.timestamp))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 62, alignment: .leading)

                            Circle()
                                .fill(Color(nsColor: colorForKind(entry.kind)))
                                .frame(width: 7, height: 7)

                            Text(entry.message)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .id(entry.id)
                    }
                }
                .padding(12)
            }
            .frame(minHeight: 160)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator, lineWidth: 1)
            )
            .task(id: entries.last?.id) {
                let lastID = entries.last?.id
                if let lastID {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
