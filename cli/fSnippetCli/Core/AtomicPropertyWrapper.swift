import Foundation

/// 원자성을 보장하는 프로퍼티 래퍼
/// 스레드 안전한 값 접근과 수정을 제공
@propertyWrapper
struct Atomic<T> {
    private let queue = DispatchQueue(label: "atomic.\(UUID().uuidString)", attributes: .concurrent)
    private var _value: T
    
    init(wrappedValue: T) {
        _value = wrappedValue
    }
    
    var wrappedValue: T {
        get {
            return queue.sync { _value }
        }
        set {
            queue.sync(flags: .barrier) {
                self._value = newValue
            }
        }
    }
    
    /// 원자적 업데이트를 위한 메서드
    /// 현재 값을 기반으로 새 값을 계산하고 원자적으로 업데이트
    mutating func modify<Result>(_ action: (inout T) -> Result) -> Result {
        return queue.sync(flags: .barrier) {
            return action(&_value)
        }
    }
    
    /// 현재 값을 읽고 변경 여부를 결정하는 조건부 업데이트
    func withValue<Result>(_ action: (T) -> Result) -> Result {
        return queue.sync {
            return action(_value)
        }
    }
}

/// Bool 타입 특화 Atomic 래퍼 - 토글 기능 제공
extension Atomic where T == Bool {
    /// 원자적 토글 연산
    @discardableResult
    mutating func toggle() -> Bool {
        return modify { value in
            value.toggle()
            return value
        }
    }
}

/// Int 타입 특화 Atomic 래퍼 - 증감 연산 제공
extension Atomic where T == Int {
    /// 원자적 증가 연산
    @discardableResult
    mutating func increment(by amount: Int = 1) -> Int {
        return modify { value in
            value += amount
            return value
        }
    }
    
    /// 원자적 감소 연산
    @discardableResult
    mutating func decrement(by amount: Int = 1) -> Int {
        return modify { value in
            value -= amount
            return value
        }
    }
}

/// Array 타입 특화 Atomic 래퍼 - 컬렉션 조작 제공
extension Atomic where T: RangeReplaceableCollection {
    /// 원자적 요소 추가
    mutating func append(_ element: T.Element) {
        modify { collection in
            collection.append(element)
        }
    }
    
    /// 원자적 요소 제거
    @discardableResult
    mutating func removeLast() -> T.Element? where T: BidirectionalCollection {
        return modify { collection in
            return collection.isEmpty ? nil : collection.removeLast()
        }
    }
    
    /// 원자적 전체 제거
    mutating func removeAll() {
        modify { collection in
            collection.removeAll()
        }
    }
}

// MARK: - 사용 예시 및 테스트

/// Atomic 프로퍼티 래퍼 사용 예시
class AtomicExample {
    @Atomic private var counter = 0
    @Atomic private var isEnabled = false
    @Atomic private var items: [String] = []
    
    func incrementCounter() {
        _counter.increment()
    }
    
    func toggleEnabled() {
        _isEnabled.toggle()
    }
    
    func addItem(_ item: String) {
        _items.append(item)
    }
    
    func getCurrentStats() -> (count: Int, enabled: Bool, itemCount: Int) {
        return (counter, isEnabled, items.count)
    }
}