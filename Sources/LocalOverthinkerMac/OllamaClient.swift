import Foundation

struct OllamaClient {
    let settings: OllamaSettings

    init(settings: OllamaSettings = .default) {
        self.settings = settings
    }

    func checkHealth() async -> Bool {
        do {
            let request = URLRequest(url: settings.baseURL.appendingPathComponent("api/tags"))
            _ = try await performData(for: request, timeout: 8)
            return true
        } catch {
            return false
        }
    }

    func listModels() async throws -> [String] {
        let request = URLRequest(url: settings.baseURL.appendingPathComponent("api/tags"))
        let data = try await performData(for: request, timeout: 8)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = object["models"] as? [[String: Any]] else {
            return []
        }

        return models
            .compactMap { model in
                (model["model"] as? String) ?? (model["name"] as? String)
            }
            .sorted()
    }

    func embedText(_ input: String) async throws -> [Double] {
        var request = URLRequest(url: settings.baseURL.appendingPathComponent("api/embed"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": settings.embeddingModel,
            "input": input
        ])

        do {
            let data = try await performData(for: request, timeout: 20)
            if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let embedding = object["embedding"] as? [Double] {
                    return embedding
                }

                if let embeddings = object["embeddings"] as? [[Double]], let first = embeddings.first {
                    return first
                }
            }
        } catch {
            var fallback = URLRequest(url: settings.baseURL.appendingPathComponent("api/embeddings"))
            fallback.httpMethod = "POST"
            fallback.setValue("application/json", forHTTPHeaderField: "Content-Type")
            fallback.httpBody = try JSONSerialization.data(withJSONObject: [
                "model": settings.embeddingModel,
                "prompt": input
            ])
            let data = try await performData(for: fallback, timeout: 20)

            if let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let embedding = object["embedding"] as? [Double] {
                return embedding
            }
        }

        throw NSError(domain: "OllamaClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Embedding model did not return a vector."])
    }

    func generateReflection(system: String, user: String) async throws -> String {
        var request = URLRequest(url: settings.baseURL.appendingPathComponent("api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": settings.reflectionModel,
            "stream": false,
            "keep_alive": settings.runtime.keepAlive,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "options": [
                "temperature": settings.runtime.temperature,
                "num_ctx": settings.runtime.numContextTokens,
                "num_predict": settings.runtime.maxOutputTokens,
                "num_thread": settings.runtime.numThreads
            ]
        ])

        let data = try await performData(for: request, timeout: 45)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = object?["message"] as? [String: Any]
        let content = (message?["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !content.isEmpty else {
            throw NSError(domain: "OllamaClient", code: 3, userInfo: [NSLocalizedDescriptionKey: "Reflection model returned an empty response."])
        }

        return content
    }

    private func performData(for request: URLRequest, timeout: TimeInterval) async throws -> Data {
        let session = URLSession(configuration: .default)
        var timedRequest = request
        timedRequest.timeoutInterval = timeout
        let (data, response) = try await session.data(for: timedRequest)

        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw NSError(domain: "OllamaClient", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }

        return data
    }
}
