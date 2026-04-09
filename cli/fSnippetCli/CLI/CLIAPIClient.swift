import Foundation

// MARK: - CLI API 클라이언트

/// 실행 중인 fSnippetCli 인스턴스의 REST API를 호출하는 동기식 HTTP 클라이언트
struct CLIAPIClient {

    let port: UInt16

    init(port: UInt16 = 3015) {
        self.port = port
    }

    /// API 호출 결과
    struct APIResult {
        let statusCode: Int
        let data: Data?
        let error: Error?

        var isSuccess: Bool { statusCode >= 200 && statusCode < 300 }

        var jsonString: String? {
            guard let data = data else { return nil }
            return String(data: data, encoding: .utf8)
        }

        func decoded<T: Decodable>(_ type: T.Type) -> T? {
            guard let data = data else { return nil }
            return try? JSONDecoder().decode(type, from: data)
        }

        func jsonDict() -> [String: Any]? {
            guard let data = data else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
    }

    // MARK: - HTTP 메서드

    /// GET 요청
    func get(path: String, query: [String: String] = [:]) -> APIResult {
        var urlString = "http://localhost:\(port)\(path)"
        if !query.isEmpty {
            let queryString = query.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
                .joined(separator: "&")
            urlString += "?\(queryString)"
        }

        guard let url = URL(string: urlString) else {
            return APIResult(statusCode: 0, data: nil, error: CLIError.invalidURL(urlString))
        }

        return syncRequest(URLRequest(url: url))
    }

    /// POST 요청
    func post(path: String, body: [String: Any]? = nil) -> APIResult {
        let urlString = "http://localhost:\(port)\(path)"
        guard let url = URL(string: urlString) else {
            return APIResult(statusCode: 0, data: nil, error: CLIError.invalidURL(urlString))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        return syncRequest(request)
    }

    // MARK: - 동기식 URLSession 호출

    private func syncRequest(_ request: URLRequest) -> APIResult {
        let semaphore = DispatchSemaphore(value: 0)
        var result = APIResult(statusCode: 0, data: nil, error: nil)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            result = APIResult(statusCode: statusCode, data: data, error: error)
            semaphore.signal()
        }
        task.resume()

        let timeout = semaphore.wait(timeout: .now() + 10)
        if timeout == .timedOut {
            task.cancel()
            return APIResult(statusCode: 0, data: nil, error: CLIError.timeout)
        }

        return result
    }

    // MARK: - 서비스 상태 확인

    /// fSnippetCli 서비스가 실행 중인지 확인
    func isServiceRunning() -> Bool {
        let result = get(path: "/")
        return result.isSuccess
    }
}

// MARK: - CLI 에러

enum CLIError: Error, CustomStringConvertible {
    case serviceNotRunning
    case invalidURL(String)
    case timeout
    case apiError(Int, String)

    var description: String {
        switch self {
        case .serviceNotRunning:
            return "fSnippetCli 서비스가 실행 중이 아닙니다.\n  → brew services start fsnippetcli 로 시작해주세요"
        case .invalidURL(let url):
            return "잘못된 URL: \(url)"
        case .timeout:
            return "API 요청 시간 초과 (10초)"
        case .apiError(let code, let message):
            return "API 오류 (\(code)): \(message)"
        }
    }

    var exitCode: Int32 {
        switch self {
        case .serviceNotRunning: return 3
        case .timeout: return 4
        case .apiError: return 4
        case .invalidURL: return 1
        }
    }
}
