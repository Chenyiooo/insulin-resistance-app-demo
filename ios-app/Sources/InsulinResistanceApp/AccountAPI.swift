import Foundation

struct UserAccount: Codable {
    let id: String
    let email: String
    let name: String
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: UserAccount
}

struct AccountAPIError: Codable {
    let detail: String
}

struct ProfileEnvelope<T: Codable>: Codable {
    let data: T
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case data
        case updatedAt = "updated_at"
    }
}

struct CheckInEnvelope<T: Codable>: Codable {
    let id: String?
    let checkInDate: String?
    let source: String?
    let provenance: [String: String]?
    let data: T
    let modelPayload: ModelInputPayload?
    let riskResult: RiskPredictionResponse?

    enum CodingKeys: String, CodingKey {
        case id
        case checkInDate = "checkin_date"
        case source
        case provenance
        case data
        case modelPayload = "model_payload"
        case riskResult = "risk_result"
    }
}

struct AccountAPI {
    var baseURL = AppEnvironment.apiBaseURL
    var session: URLSession = .shared

    func register(email: String, password: String, name: String) async throws -> AuthResponse {
        try await auth(path: "auth/register", email: email, password: password, name: name)
    }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await auth(path: "auth/login", email: email, password: password, name: nil)
    }

    func fetchProfile(token: String) async throws -> UserProfile? {
        let request = authorizedRequest(path: "me/profile", token: token)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RiskPredictionAPIError.invalidResponse
        }
        if httpResponse.statusCode == 200 {
            if data.isEmpty || String(data: data, encoding: .utf8) == "null" {
                return nil
            }
            return try JSONDecoder().decode(ProfileEnvelope<UserProfile>.self, from: data).data
        }
        throw decodeServerError(data: data, statusCode: httpResponse.statusCode)
    }

    func saveProfile(_ profile: UserProfile, token: String) async throws {
        var request = authorizedRequest(path: "me/profile", token: token)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ProfileEnvelope(data: profile, updatedAt: nil))
        _ = try await validatedData(for: request)
    }

    func fetchLatestCheckIn(token: String) async throws -> DailyCheckIn? {
        let request = authorizedRequest(path: "me/checkins/latest", token: token)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RiskPredictionAPIError.invalidResponse
        }
        if httpResponse.statusCode == 200 {
            if data.isEmpty || String(data: data, encoding: .utf8) == "null" {
                return nil
            }
            return try JSONDecoder().decode(CheckInEnvelope<DailyCheckIn>.self, from: data).data
        }
        throw decodeServerError(data: data, statusCode: httpResponse.statusCode)
    }

    func saveCheckIn(
        _ checkIn: DailyCheckIn,
        token: String,
        modelPayload: ModelInputPayload,
        riskResult: RiskPredictionResponse?,
        source: String,
        provenance: [String: String]
    ) async throws {
        var request = authorizedRequest(path: "me/checkins", token: token)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            CheckInEnvelope(
                id: nil,
                checkInDate: Self.todayString(),
                source: source,
                provenance: provenance.isEmpty ? nil : provenance,
                data: checkIn,
                modelPayload: modelPayload,
                riskResult: riskResult
            )
        )
        _ = try await validatedData(for: request)
    }

    func deleteAccount(token: String) async throws {
        var request = authorizedRequest(path: "me", token: token)
        request.httpMethod = "DELETE"
        _ = try await validatedData(for: request)
    }

    func exportAccountData(token: String) async throws -> Data {
        let request = authorizedRequest(path: "me/export", token: token)
        return try await validatedData(for: request)
    }

    private func auth(path: String, email: String, password: String, name: String?) async throws -> AuthResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5
        request.httpBody = try JSONEncoder().encode([
            "email": email,
            "password": password,
            "name": name ?? "",
        ])
        let data = try await validatedData(for: request)
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    private func authorizedRequest(path: String, token: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 5
        return request
    }

    private func validatedData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RiskPredictionAPIError.invalidResponse
        }
        if (200..<300).contains(httpResponse.statusCode) {
            return data
        }
        throw decodeServerError(data: data, statusCode: httpResponse.statusCode)
    }

    private func decodeServerError(data: Data, statusCode: Int) -> Error {
        if let error = try? JSONDecoder().decode(AccountAPIError.self, from: data) {
            return RiskPredictionAPIError.serverMessage(error.detail)
        }
        return RiskPredictionAPIError.serverMessage("Request failed with status \(statusCode).")
    }

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
