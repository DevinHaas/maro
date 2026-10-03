import Foundation
import CryptoKit
import Network
import Security

/// One personal desktop account. OAuth credentials never enter player state or logs.
@MainActor
public final class YouTubeAccount {
    private struct Credentials: Codable {
        var clientID: String
        var clientSecret: String
        var refreshToken: String?
    }
    private var credentials: Credentials?
    private var access: (token: String, expires: Date)?
    private var refreshTask: Task<String, Error>?
    private var callback: OAuthCallback?
    private let service: String
    public var isConfigured: Bool { credentials != nil }
    public var isConnected: Bool { credentials?.refreshToken != nil }

    public init(keychainService: String = "Maro.YouTube") throws {
        service = keychainService
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            credentials = try JSONDecoder().decode(Credentials.self, from: data)
        } else if status != errSecItemNotFound {
            throw YouTubeAccountError("Maro could not read its YouTube connection from Keychain (\(status)).")
        }
    }

    public func configure(json data: Data) throws {
        guard callback == nil, refreshTask == nil else { throw YouTubeAccountError("Wait for the current sign-in to finish.") }
        guard data.count <= 65_536,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let installed = root["installed"] as? [String: Any],
              let id = installed["client_id"] as? String, id.hasSuffix(".apps.googleusercontent.com"),
              id.utf8.count <= 512,
              let secret = installed["client_secret"] as? String, !secret.isEmpty, secret.utf8.count <= 512 else {
            throw YouTubeAccountError("Choose the JSON credentials for a Google Desktop app OAuth client.")
        }
        let new = Credentials(clientID: id, clientSecret: secret)
        try save(new)
        credentials = new
        access = nil
    }

    public func connect(openBrowser: (URL) -> Bool) async throws {
        guard let credentials else { throw YouTubeAccountError("Import your Google Desktop app credentials first.") }
        guard callback == nil else { throw YouTubeAccountError("Sign-in is already open in your browser.") }
        let verifier = try Self.random()
        let state = try Self.random()
        let callback = try OAuthCallback(state: state)
        self.callback = callback
        defer { callback.cancel(); self.callback = nil }
        let redirect = try await callback.start()
        var url = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        url.queryItems = [
            "client_id": credentials.clientID, "redirect_uri": redirect,
            "response_type": "code", "scope": "https://www.googleapis.com/auth/youtube.force-ssl",
            "access_type": "offline", "prompt": "consent", "state": state,
            "code_challenge": Self.base64(Data(SHA256.hash(data: Data(verifier.utf8)))),
            "code_challenge_method": "S256"
        ].map { URLQueryItem(name: $0.key, value: $0.value) }
        guard openBrowser(url.url!) else { throw YouTubeAccountError("Could not open your browser for Google sign-in.") }
        let code = try await callback.code()
        let response = try await exchange([
            "grant_type": "authorization_code", "code": code, "redirect_uri": redirect,
            "code_verifier": verifier, "client_id": credentials.clientID, "client_secret": credentials.clientSecret
        ])
        try Task.checkCancellation()
        guard let refresh = response["refresh_token"] as? String, !refresh.isEmpty else {
            throw YouTubeAccountError("Google did not grant offline access. Connect again and approve playlist access.")
        }
        var updated = credentials
        updated.refreshToken = refresh
        try save(updated)
        self.credentials = updated
        _ = try accept(response)
    }

    public func cancelSignIn() { callback?.cancel() }

    public func disconnect() throws {
        callback?.cancel()
        refreshTask?.cancel(); refreshTask = nil
        guard var updated = credentials else { return }
        updated.refreshToken = nil
        try save(updated)
        credentials = updated; access = nil
    }

    public func accessToken() async throws -> String {
        if let access, access.expires.timeIntervalSinceNow > 60 { return access.token }
        if let refreshTask { return try await refreshTask.value }
        guard let credentials, let refresh = credentials.refreshToken else {
            throw YouTubeAccountError("Connect your YouTube account first.")
        }
        let task = Task { @MainActor in
            let response = try await self.exchange([
                "grant_type": "refresh_token", "refresh_token": refresh,
                "client_id": credentials.clientID, "client_secret": credentials.clientSecret
            ])
            try Task.checkCancellation()
            return try self.accept(response)
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func accept(_ response: [String: Any]) throws -> String {
        guard let token = response["access_token"] as? String, !token.isEmpty,
              let expires = response["expires_in"] as? Double, expires > 0 else {
            throw YouTubeAccountError("Google returned an incomplete sign-in response. Connect again.")
        }
        access = (token, Date().addingTimeInterval(expires))
        return token
    }

    private func exchange(_ fields: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"; request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        request.httpBody = fields.sorted { $0.key < $1.key }.map {
            "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: safe)!)"
        }.joined(separator: "&").data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YouTubeAccountError("Google could not authorize Maro. Connect again; check your consent settings if this persists.")
        }
        return json
    }

    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "personal-youtube"]
    }

    private func save(_ credentials: Credentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let status = SecItemUpdate(keychainQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var query = keychainQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(query as CFDictionary, nil)
            guard added == errSecSuccess else { throw YouTubeAccountError("Could not save the YouTube connection in Keychain (\(added)).") }
        } else if status != errSecSuccess {
            throw YouTubeAccountError("Could not update the YouTube connection in Keychain (\(status)).")
        }
    }

    private static func random() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw YouTubeAccountError("Could not securely start Google sign-in.")
        }
        return base64(Data(bytes))
    }

    private static func base64(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

/// Short-lived loopback receiver: no public interface, cookies, or credentials in URLs sent onward.
@MainActor
final class OAuthCallback {
    private let listener: NWListener
    private let state: String
    private var ready: CheckedContinuation<String, Error>?
    private var waiting: CheckedContinuation<String, Error>?
    private var result: Result<String, Error>?
    private var timeout: Task<Void, Never>?
    private var connections: [NWConnection] = []

    init(state: String) throws {
        self.state = state
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }

    func start() async throws -> String {
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(180)) } catch { return }
            self?.finish(.failure(YouTubeAccountError("Google sign-in timed out. Connect again to retry.")))
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                ready = continuation
                listener.stateUpdateHandler = { [weak self] status in
                    Task { @MainActor in
                        guard let self else { return }
                        switch status {
                        case .ready:
                            if let port = self.listener.port {
                                self.ready?.resume(returning: "http://127.0.0.1:\(port.rawValue)/oauth/callback")
                                self.ready = nil
                            }
                        case .failed: self.finish(.failure(YouTubeAccountError("Could not start the local Google sign-in callback.")))
                        default: break
                        }
                    }
                }
                listener.newConnectionHandler = { [weak self] connection in
                    Task { @MainActor in
                        guard let self, self.result == nil, self.connections.count < 8 else { connection.cancel(); return }
                        self.connections.append(connection)
                        connection.start(queue: .main)
                        self.receive(connection, data: Data())
                    }
                }
                listener.start(queue: .main)
            }
        } onCancel: { Task { @MainActor in self.cancel() } }
    }

    func code() async throws -> String {
        try await withTaskCancellationHandler {
            if let result { return try result.get() }
            return try await withCheckedThrowingContinuation { waiting = $0 }
        } onCancel: { Task { @MainActor in self.cancel() } }
    }

    func cancel() { finish(.failure(CancellationError())) }

    private func receive(_ connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] chunk, _, complete, error in
            Task { @MainActor in
                guard let self, self.result == nil else { connection.cancel(); return }
                var buffer = data
                if let chunk { buffer.append(chunk) }
                guard buffer.count <= 16_384, error == nil else { self.close(connection); return }
                guard let text = String(data: buffer, encoding: .utf8), text.contains("\r\n\r\n") else {
                    if complete { self.close(connection) } else { self.receive(connection, data: buffer) }
                    return
                }
                let parts = text.components(separatedBy: "\r\n")[0].split(separator: " ")
                guard parts.count == 3, parts[0] == "GET",
                      let url = URLComponents(string: String(parts[1])), url.path == "/oauth/callback" else {
                    self.close(connection); return
                }
                let fields = url.queryItems ?? []
                guard fields.filter({ $0.name == "state" }).count == 1,
                      fields.first(where: { $0.name == "state" })?.value == self.state else {
                    self.close(connection); return
                }
                let result: Result<String, Error>
                if fields.contains(where: { $0.name == "error" }) {
                    result = .failure(YouTubeAccountError("Google sign-in was declined. Connect again when ready."))
                } else if fields.filter({ $0.name == "code" }).count == 1,
                          let code = fields.first(where: { $0.name == "code" })?.value, !code.isEmpty {
                    result = .success(code)
                } else { self.close(connection); return }
                let body = "You can close this tab and return to Maro."
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nCache-Control: no-store\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
                self.connections.removeAll { $0 === connection }
                self.finish(result)
            }
        }
    }

    private func close(_ connection: NWConnection) {
        connection.cancel(); connections.removeAll { $0 === connection }
    }

    private func finish(_ result: Result<String, Error>) {
        guard self.result == nil else { return }
        self.result = result
        timeout?.cancel(); timeout = nil
        listener.cancel()
        connections.forEach { $0.cancel() }; connections.removeAll()
        if let ready { ready.resume(throwing: YouTubeAccountError("Google sign-in could not start.")); self.ready = nil }
        waiting?.resume(with: result); waiting = nil
    }
}
