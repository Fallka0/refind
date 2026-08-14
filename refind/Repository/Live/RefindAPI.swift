//
//  RefindAPI.swift
//  refind
//
//  Transport for the contract in docs/API.md. No server implements this yet —
//  the point is that the contract is written down in one place and the client
//  compiles against it, so standing a backend up is the only remaining step.
//

import Foundation

struct RefindEnvironment: Sendable {
    let baseURL: URL

    static let production = RefindEnvironment(
        baseURL: URL(string: "https://api.refind.ch/v1")!
    )
    static let staging = RefindEnvironment(
        baseURL: URL(string: "https://api.staging.refind.ch/v1")!
    )
}

/// Holds the token pair. A real build swaps this for the Keychain — tokens in
/// memory only is deliberate here rather than accidentally persisting them
/// somewhere insecure.
actor TokenStore {
    private var accessToken: String?
    private var refreshToken: String?

    func tokens() -> (access: String?, refresh: String?) { (accessToken, refreshToken) }

    func update(access: String?, refresh: String?) {
        accessToken = access
        refreshToken = refresh
    }

    func clear() { accessToken = nil; refreshToken = nil }
}

/// The error body every non-2xx response carries.
struct APIProblem: Decodable, Sendable {
    let code: String
    let message: String
    let field: String?
}

actor RefindAPI {

    private let environment: RefindEnvironment
    private let session: URLSession
    private let tokens: TokenStore

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = RefindAPI.rfc3339.date(from: raw) else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Expected RFC 3339, got \(raw)"
                )
            }
            return date
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(RefindAPI.rfc3339.string(from: date))
        }
        return e
    }()

    static let rfc3339: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init(environment: RefindEnvironment = .production,
         session: URLSession = .shared,
         tokens: TokenStore = TokenStore()) {
        self.environment = environment
        self.session = session
        self.tokens = tokens
    }

    // MARK: Requests

    enum Method: String { case get = "GET", post = "POST", put = "PUT",
                          patch = "PATCH", delete = "DELETE" }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await send(path, method: .get, query: query, body: Optional<Empty>.none)
    }

    @discardableResult
    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        try await send(path, method: .post, body: body)
    }

    func postNoContent<Body: Encodable>(_ path: String, body: Body) async throws {
        _ = try await sendRaw(path, method: .post, query: [:], body: body)
    }

    func postNoContent(_ path: String) async throws {
        _ = try await sendRaw(path, method: .post, query: [:], body: Optional<Empty>.none)
    }

    func putNoContent<Body: Encodable>(_ path: String, body: Body) async throws {
        _ = try await sendRaw(path, method: .put, query: [:], body: body)
    }

    func patch<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        try await send(path, method: .patch, body: body)
    }

    func deleteNoContent(_ path: String) async throws {
        _ = try await sendRaw(path, method: .delete, query: [:], body: Optional<Empty>.none)
    }

    private struct Empty: Codable {}

    private func send<Body: Encodable, T: Decodable>(
        _ path: String, method: Method, query: [String: String] = [:], body: Body?
    ) async throws -> T {
        let data = try await sendRaw(path, method: method, query: query, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // A shape mismatch is a server bug, not something to show a user.
            throw RepositoryError.server
        }
    }

    /// One refresh-and-retry on 401, then give up.
    private func sendRaw<Body: Encodable>(
        _ path: String, method: Method, query: [String: String], body: Body?
    ) async throws -> Data {
        do {
            return try await perform(path, method: method, query: query, body: body)
        } catch RepositoryError.unauthorized {
            try await refreshTokens()
            return try await perform(path, method: method, query: query, body: body)
        } catch RepositoryError.rateLimited(let retryAfter) {
            try? await Task.sleep(for: .seconds(retryAfter))
            return try await perform(path, method: method, query: query, body: body)
        }
    }

    private func perform<Body: Encodable>(
        _ path: String, method: Method, query: [String: String], body: Body?
    ) async throws -> Data {
        var components = URLComponents(
            url: environment.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        if !query.isEmpty {
            components?.queryItems = query
                .filter { !$0.value.isEmpty }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw RepositoryError.server }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let access = await tokens.tokens().access {
            request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where Self.offlineCodes.contains(error.code) {
            throw RepositoryError.offline
        } catch {
            throw RepositoryError.server
        }

        guard let http = response as? HTTPURLResponse else { throw RepositoryError.server }
        if http.statusCode == 429 {
            // Honour the server's own backoff once rather than hammering it.
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")
                              .flatMap(Double.init)) ?? 1
            throw RepositoryError.rateLimited(retryAfter: min(retryAfter, 60))
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Self.error(for: http.statusCode, data: data, decoder: decoder)
        }
        return data
    }

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost,
        .dataNotAllowed, .cannotConnectToHost, .timedOut
    ]

    /// The server owns validation copy, so 400/409 messages are shown verbatim.
    private static func error(for status: Int, data: Data,
                              decoder: JSONDecoder) -> RepositoryError {
        let problem = try? decoder.decode(APIProblem.self, from: data)
        switch status {
        case 400, 409: return .invalidInput(problem?.message ?? RepositoryError.server.inlineMessage)
        case 401:      return .unauthorized
        case 404:      return .notFound
        default:       return .server
        }
    }

    private func refreshTokens() async throws {
        guard let refresh = await tokens.tokens().refresh else {
            await tokens.clear()
            throw RepositoryError.server
        }
        struct Request: Encodable { let refreshToken: String }
        struct Response: Decodable {
            let accessToken: String
            let refreshToken: String
        }
        // Deliberately not through sendRaw — a 401 here must not recurse.
        let response: Response = try await send("auth/refresh", method: .post,
                                                body: Request(refreshToken: refresh))
        await tokens.update(access: response.accessToken, refresh: response.refreshToken)
    }
}
