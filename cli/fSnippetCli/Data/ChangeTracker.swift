import Foundation

// MARK: - 변경 추적기

/// CLI 측 변경 사항을 시퀀스 번호로 추적하여 GUI 폴링에 제공
/// 설계 문서: _doc_design/event/design_event-notification.md
final class ChangeTracker {
  static let shared = ChangeTracker()

  private let queue = DispatchQueue(label: "kr.finfra.fSnippetCli.changeTracker")
  private var _currentSeq: Int = 0
  private var _history: [ChangeEvent] = []
  private let maxHistory = 100

  // debounce: 0.5초 내 동일 타입 이벤트 병합
  private var debounceTimers: [String: DispatchWorkItem] = [:]
  private let debounceInterval: TimeInterval = 0.5

  private init() {}

  /// 현재 시퀀스 번호
  var currentSeq: Int {
    queue.sync { _currentSeq }
  }

  /// 변경 이벤트 기록 (debounce 적용)
  func record(type: String, target: String) {
    let key = "\(type):\(target)"

    queue.async { [weak self] in
      guard let self else { return }

      // 기존 debounce 타이머 취소
      self.debounceTimers[key]?.cancel()

      let workItem = DispatchWorkItem { [weak self] in
        guard let self else { return }
        self.queue.async {
          self._currentSeq += 1
          let event = ChangeEvent(
            seq: self._currentSeq,
            type: type,
            target: target,
            timestamp: ISO8601DateFormatter().string(from: Date())
          )
          self._history.append(event)

          // 링버퍼: 최대 100건 유지
          if self._history.count > self.maxHistory {
            self._history.removeFirst(self._history.count - self.maxHistory)
          }

          self.debounceTimers.removeValue(forKey: key)
          logD("🔔 [ChangeTracker] seq=\(event.seq) type=\(type) target=\(target)")
        }
      }

      self.debounceTimers[key] = workItem
      DispatchQueue.global().asyncAfter(
        deadline: .now() + self.debounceInterval, execute: workItem)
    }
  }

  /// 즉시 기록 (debounce 없이)
  func recordImmediate(type: String, target: String) {
    queue.sync {
      _currentSeq += 1
      let event = ChangeEvent(
        seq: _currentSeq,
        type: type,
        target: target,
        timestamp: ISO8601DateFormatter().string(from: Date())
      )
      _history.append(event)
      if _history.count > maxHistory {
        _history.removeFirst(_history.count - maxHistory)
      }
      logD("🔔 [ChangeTracker] (즉시) seq=\(event.seq) type=\(type) target=\(target)")
    }
  }

  /// since 이후의 변경 목록 반환
  func changesSince(_ since: Int) -> ChangeResponse {
    queue.sync {
      let filtered = _history.filter { $0.seq > since }
      return ChangeResponse(currentSeq: _currentSeq, changes: filtered)
    }
  }
}

// MARK: - 모델

struct ChangeEvent: Codable {
  let seq: Int
  let type: String
  let target: String
  let timestamp: String
}

struct ChangeResponse: Codable {
  let currentSeq: Int
  let changes: [ChangeEvent]
}
