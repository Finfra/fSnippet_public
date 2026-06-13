import Foundation
import Network

/// NWListener 기반 경량 REST API HTTP 서버
class APIServer {
  static let shared = APIServer()

  private var listener: NWListener?
  private let queue = DispatchQueue(label: "com.nowage.fSnippet.apiServer", qos: .utility)
  private let cidrFilter = CIDRFilter()
  private var startTime = Date()
  private(set) var isRunning = false
  private(set) var currentPort: UInt16 = 3015

  // MARK: - Pause / Resume (Issue100)

  /// API pause 상태. true 시 health/cli/* 외 모든 요청은 503 반환.
  private(set) var isApiPaused: Bool = false

  func pauseAPI() {
    isApiPaused = true
    logI("🌐 API paused (via menu)")
  }

  func resumeAPI() {
    isApiPaused = false
    logI("🌐 API resumed (via menu)")
  }

  private init() {}

  // MARK: - 서버 제어

  /// 서버 시작
  /// - Parameter forceEnabled: true면 api_enabled 체크를 스킵 (UI에서 직접 호출 시 타이밍 이슈 방지)
  func start(forceEnabled: Bool = false) {
    guard !isRunning else {
      logW("🌐 API 서버가 이미 실행 중입니다")
      return
    }

    if !forceEnabled {
      let enabled: Bool = PreferencesManager.shared.get("api_enabled") ?? false
      guard enabled else {
        logI("🌐 API 서버가 비활성화 상태입니다")
        return
      }
    }

    let port: Int = PreferencesManager.shared.get("api_port") ?? 3015
    let cidr = PreferencesManager.shared.string(forKey: "api_allowed_cidr", defaultValue: "127.0.0.1/32")
    let allowExternal: Bool = PreferencesManager.shared.get("api_allow_external") ?? false

    if allowExternal {
      cidrFilter.update(cidr: cidr)
    } else {
      cidrFilter.update(cidr: "127.0.0.1/32")
    }

    currentPort = UInt16(port)

    do {
      let nwPort = NWEndpoint.Port(rawValue: currentPort)!
      let params = NWParameters.tcp

      listener = try NWListener(using: params, on: nwPort)

      listener?.stateUpdateHandler = { [weak self] state in
        switch state {
        case .ready:
          self?.isRunning = true
          self?.startTime = Date()
          logI("🌐 API 서버 시작됨 - 포트: \(port)")
        case .failed(let error):
          self?.isRunning = false
          logE("🌐 ❌ API 서버 실패: \(error)")
        case .cancelled:
          self?.isRunning = false
          logI("🌐 API 서버 중지됨")
        default:
          break
        }
      }

      listener?.newConnectionHandler = { [weak self] connection in
        self?.handleConnection(connection)
      }

      listener?.start(queue: queue)

    } catch {
      logE("🌐 ❌ API 서버 시작 실패: \(error)")
    }
  }

  /// 서버 중지
  func stop() {
    listener?.cancel()
    listener = nil
    isRunning = false
    logI("🌐 API 서버 중지 요청")
  }

  /// 서버 재시작
  func restart() {
    stop()
    queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.start()
    }
  }

  /// 서버 가동 시간 (초)
  var uptimeSeconds: Int {
    guard isRunning else { return 0 }
    return Int(Date().timeIntervalSince(startTime))
  }

  // MARK: - HTTP 요청/응답 구조체

  struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data?
    /// 원격 클라이언트 IP (v2 쓰기 경로의 localhost 강제 가드용)
    let remoteIP: String
  }

  struct HTTPResponse {
    let statusCode: Int
    let body: String
    /// JSON 인코딩된 원본 Data — 제어문자 이스케이프 보존을 위해 String 변환 없이 직접 전송
    let rawBodyData: Data?
    let headers: [String: String]

    init(statusCode: Int, body: String, headers: [String: String] = [:]) {
      self.statusCode = statusCode
      self.body = body
      self.rawBodyData = nil
      self.headers = headers
    }

    /// Data 기반 초기화 — JSONEncoder 출력을 String 변환 없이 보존
    init(statusCode: Int, bodyData: Data, headers: [String: String] = [:]) {
      self.statusCode = statusCode
      self.body = ""
      self.rawBodyData = bodyData
      self.headers = headers
    }
  }

  // MARK: - 연결 처리

  private func handleConnection(_ connection: NWConnection) {
    connection.start(queue: queue)

    let remoteIP = extractIP(from: connection.endpoint)
    guard cidrFilter.isAllowed(remoteIP) else {
      logW("🌐 접근 거부: \(remoteIP)")
      let body = "{\"success\":false,\"error\":{\"code\":\"FORBIDDEN\",\"message\":\"Access denied\"}}"
      sendAndClose(connection: connection, data: buildHTTPResponse(statusCode: 403, body: body))
      return
    }

    receiveHTTPRequest(connection: connection, remoteIP: remoteIP, accumulated: Data())
  }

  // Accumulate received data until the full HTTP request (headers + Content-Length body bytes)
  // is present before processing. Defends against NWConnection partial reads (Issue923):
  // receive(minimumIncompleteLength:1) fires on the first byte, so headers and body may
  // arrive in separate callbacks — causing body == nil and HTTP 400 on re-register.
  private func receiveHTTPRequest(connection: NWConnection, remoteIP: String, accumulated: Data) {
    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
      guard let self = self else { return }

      var buffer = accumulated
      if let data = data, !data.isEmpty { buffer.append(data) }
      guard !buffer.isEmpty else { connection.cancel(); return }

      // Find header/body separator
      let separator = Data([0x0D, 0x0A, 0x0D, 0x0A])
      guard let sepRange = buffer.range(of: separator) else {
        // Headers not yet complete — guard against oversized headers (>8 KB)
        guard buffer.count < 8192 else { connection.cancel(); return }
        self.receiveHTTPRequest(connection: connection, remoteIP: remoteIP, accumulated: buffer)
        return
      }

      // Parse Content-Length from headers
      let headerData = buffer[..<sepRange.lowerBound]
      let headerString = String(data: headerData, encoding: .utf8) ?? ""
      let contentLength: Int = headerString
        .components(separatedBy: "\r\n")
        .compactMap { line -> Int? in
          let lower = line.lowercased()
          guard lower.hasPrefix("content-length:") else { return nil }
          return Int(lower.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces))
        }
        .first ?? 0

      // Check if body is fully received
      let receivedBodyLength = buffer.count - sepRange.upperBound
      if contentLength > 0 && receivedBodyLength < contentLength {
        // Body not yet complete — guard against oversized bodies (>64 KB)
        guard buffer.count < 65536 else { connection.cancel(); return }
        self.receiveHTTPRequest(connection: connection, remoteIP: remoteIP, accumulated: buffer)
        return
      }

      // Full request received — process it
      guard let requestString = String(data: buffer, encoding: .utf8) else {
        connection.cancel()
        return
      }

      let request = self.parseHTTPRequest(requestString, remoteIP: remoteIP)

      // Pause guard (Issue100): only /api/v2/cli/* bypasses pause; all others return 503
      if self.isApiPaused && !request.path.hasPrefix("/api/v2/cli/") {
        let body = "{\"success\":false,\"error\":{\"code\":\"SERVICE_UNAVAILABLE\",\"message\":\"API is paused. Use POST /api/v2/cli/resume to resume.\"}}"
        self.sendAndClose(connection: connection, data: self.buildHTTPResponse(statusCode: 503, body: body))
        return
      }

      let response = APIRouter.shared.route(request: request, server: self)
      self.sendAndClose(connection: connection, data: self.buildHTTPResponse(statusCode: response.statusCode, body: response.body, headers: response.headers, rawBodyData: response.rawBodyData))
    }
  }

  private func extractIP(from endpoint: NWEndpoint) -> String {
    switch endpoint {
    case .hostPort(let host, _):
      return "\(host)"
    default:
      return "unknown"
    }
  }

  // MARK: - HTTP 파싱

  private func parseHTTPRequest(_ raw: String, remoteIP: String) -> HTTPRequest {
    let lines = raw.components(separatedBy: "\r\n")
    guard let requestLine = lines.first else {
      return HTTPRequest(method: "GET", path: "/", query: [:], headers: [:], body: nil, remoteIP: remoteIP)
    }

    let parts = requestLine.split(separator: " ")
    let method = parts.count > 0 ? String(parts[0]) : "GET"
    let fullPath = parts.count > 1 ? String(parts[1]) : "/"

    let pathQuery = fullPath.split(separator: "?", maxSplits: 1)
    let path = String(pathQuery[0])
    var query: [String: String] = [:]

    if pathQuery.count > 1 {
      for pair in String(pathQuery[1]).split(separator: "&") {
        let kv = pair.split(separator: "=", maxSplits: 1)
        if kv.count == 2 {
          let key = String(kv[0]).removingPercentEncoding ?? String(kv[0])
          let value = String(kv[1]).removingPercentEncoding ?? String(kv[1])
          query[key] = value
        }
      }
    }

    var headers: [String: String] = [:]
    var bodyData: Data? = nil
    for i in 1..<lines.count {
      if lines[i].isEmpty {
        if i + 1 < lines.count {
          let bodyString = lines[(i + 1)...].joined(separator: "\r\n")
          bodyData = bodyString.data(using: .utf8)
        }
        break
      }
      let headerParts = lines[i].split(separator: ":", maxSplits: 1)
      if headerParts.count == 2 {
        headers[String(headerParts[0]).trimmingCharacters(in: .whitespaces).lowercased()] =
          String(headerParts[1]).trimmingCharacters(in: .whitespaces)
      }
    }

    return HTTPRequest(method: method, path: path, query: query, headers: headers, body: bodyData, remoteIP: remoteIP)
  }

  func buildHTTPResponse(statusCode: Int, body: String, headers: [String: String] = [:], rawBodyData: Data? = nil) -> Data {
    let statusText: String
    switch statusCode {
    case 200: statusText = "OK"
    case 400: statusText = "Bad Request"
    case 403: statusText = "Forbidden"
    case 404: statusText = "Not Found"
    case 405: statusText = "Method Not Allowed"
    case 500: statusText = "Internal Server Error"
    case 503: statusText = "Service Unavailable"
    default: statusText = "Unknown"
    }

    // rawBodyData가 있으면 String 변환 없이 직접 사용 (제어문자 이스케이프 보존)
    let bodyData = rawBodyData ?? (body.data(using: .utf8) ?? Data())
    var responseString = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
    responseString += "Content-Type: application/json; charset=utf-8\r\n"
    responseString += "Content-Length: \(bodyData.count)\r\n"
    responseString += "Access-Control-Allow-Origin: *\r\n"
    responseString += "Connection: close\r\n"
    for (key, value) in headers {
      responseString += "\(key): \(value)\r\n"
    }
    responseString += "\r\n"

    var data = responseString.data(using: .utf8) ?? Data()
    data.append(bodyData)
    return data
  }

  private func sendAndClose(connection: NWConnection, data: Data) {
    connection.send(content: data, completion: .contentProcessed { _ in
      connection.cancel()
    })
  }
}
