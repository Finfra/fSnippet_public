import Foundation

/// CIDR 기반 IP 접근 제어 필터
class CIDRFilter {
  private var networkAddress: UInt32 = 0
  private var subnetMask: UInt32 = 0
  private var isValid: Bool = false

  /// 기본 생성자 (localhost만 허용)
  init() {
    update(cidr: "127.0.0.1/32")
  }

  /// CIDR 문자열로 업데이트
  @discardableResult
  func update(cidr: String) -> Bool {
    let parts = cidr.split(separator: "/")
    guard parts.count == 2,
          let prefixLen = Int(parts[1]),
          prefixLen >= 0 && prefixLen <= 32,
          let ip = parseIPv4(String(parts[0])) else {
      isValid = false
      return false
    }

    subnetMask = prefixLen == 0 ? 0 : ~UInt32(0) << (32 - prefixLen)
    networkAddress = ip & subnetMask
    isValid = true
    return true
  }

  /// IP 주소가 허용 범위에 있는지 확인
  func isAllowed(_ ipString: String) -> Bool {
    let normalizedIP = (ipString == "::1" || ipString == "localhost") ? "127.0.0.1" : ipString

    let cleanIP: String
    if normalizedIP.hasPrefix("::ffff:") {
      cleanIP = String(normalizedIP.dropFirst(7))
    } else {
      cleanIP = normalizedIP
    }

    guard isValid, let ip = parseIPv4(cleanIP) else {
      return false
    }
    return (ip & subnetMask) == networkAddress
  }

  /// IPv4 문자열을 UInt32로 변환
  private func parseIPv4(_ ip: String) -> UInt32? {
    let octets = ip.split(separator: ".").compactMap { UInt8($0) }
    guard octets.count == 4 else { return nil }
    return UInt32(octets[0]) << 24 | UInt32(octets[1]) << 16 | UInt32(octets[2]) << 8 | UInt32(octets[3])
  }
}
