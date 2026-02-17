import Foundation

actor GitLabService {
    private let session: URLSession
    private let decoder: JSONDecoder

    private(set) var baseURL: URL
    private(set) var token: String

    init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        // GitLab returns dates with fractional seconds like "2025-01-15T10:30:00.123Z"
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f1.date(from: string) { return date }
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            if let date = f2.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(string)")
        }
        self.decoder = decoder
    }

    func updateCredentials(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    // MARK: - API Endpoints

    func fetchCurrentUser() async throws -> GitLabUser {
        return try await request(path: "/api/v4/user")
    }

    func fetchProjects(lastActivityAfter: Date? = nil) async throws -> [GitLabProject] {
        var all: [GitLabProject] = []
        var page = 1
        let perPage = 100

        let formatter = ISO8601DateFormatter()

        while true {
            var queryItems = [
                URLQueryItem(name: "membership", value: "true"),
                URLQueryItem(name: "simple", value: "true"),
                URLQueryItem(name: "per_page", value: "\(perPage)"),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "order_by", value: "last_activity_at"),
                URLQueryItem(name: "sort", value: "desc"),
            ]

            if let after = lastActivityAfter {
                queryItems.append(URLQueryItem(name: "last_activity_after", value: formatter.string(from: after)))
            }

            let batch: [GitLabProject] = try await request(path: "/api/v4/projects", queryItems: queryItems)
            all.append(contentsOf: batch)

            if batch.count < perPage { break }
            page += 1
        }

        return all
    }

    func fetchPipelines(
        projectID: Int,
        username: String,
        updatedAfter: Date? = nil
    ) async throws -> [Pipeline] {
        var queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "per_page", value: "5"),
            URLQueryItem(name: "order_by", value: "updated_at"),
            URLQueryItem(name: "sort", value: "desc"),
        ]

        if let after = updatedAfter {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "updated_after", value: formatter.string(from: after)))
        }

        return try await request(
            path: "/api/v4/projects/\(projectID)/pipelines",
            queryItems: queryItems
        )
    }

    func fetchJobs(
        projectID: Int,
        pipelineID: Int
    ) async throws -> [PipelineJob] {
        let queryItems = [
            URLQueryItem(name: "per_page", value: "100"),
        ]

        return try await request(
            path: "/api/v4/projects/\(projectID)/pipelines/\(pipelineID)/jobs",
            queryItems: queryItems
        )
    }

    func fetchLatestPipeline(
        projectID: Int,
        ref: String
    ) async throws -> Pipeline? {
        let queryItems = [
            URLQueryItem(name: "ref", value: ref),
            URLQueryItem(name: "per_page", value: "1"),
            URLQueryItem(name: "order_by", value: "id"),
            URLQueryItem(name: "sort", value: "desc"),
        ]

        let pipelines: [Pipeline] = try await request(
            path: "/api/v4/projects/\(projectID)/pipelines",
            queryItems: queryItems
        )
        return pipelines.first
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw GitLabError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitLabError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("[GitLabService] Decode error for \(path): \(error)")
                throw error
            }
        case 401:
            throw GitLabError.unauthorized
        case 403:
            throw GitLabError.forbidden
        case 404:
            throw GitLabError.notFound
        case 429:
            throw GitLabError.rateLimited
        default:
            throw GitLabError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Errors

enum GitLabError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitLab URL"
        case .invalidResponse:
            return "Invalid response from GitLab"
        case .unauthorized:
            return "Invalid or expired token"
        case .forbidden:
            return "Access denied -- check token scopes"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limited -- try again later"
        case .httpError(let code):
            return "HTTP error \(code)"
        }
    }
}
