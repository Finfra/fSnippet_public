import Foundation

/// Controller for managing text buffer operations.
/// Acts as a bridge between the Event Monitor and the underlying BufferManager.
class BufferController: BufferManagerDelegate {

  // MARK: - Properties

  private let bufferManager: BufferManager

  // Delegate to notify parent (KeyEventMonitor) about buffer changes
  var onBufferClear: ((String) -> Void)?

  // MARK: - Initialization

  init(bufferManager: BufferManager = BufferManager.shared) {
    self.bufferManager = bufferManager
    self.bufferManager.delegate = self
  }

  // MARK: - Public API

  func append(_ text: String) {
    bufferManager.append(text)
  }

  func removeLast() {
    bufferManager.removeLast()
  }

  func clear(reason: String) {
    bufferManager.clear(reason: reason)
  }

  func getCurrentText() -> String {
    return bufferManager.getCurrentText()
  }

  func extractSearchTerm() -> String {
    return bufferManager.extractSearchTerm()
  }

  // MARK: - BufferManagerDelegate

  func bufferDidClear(reason: String) {
    logV("🩹 🔹 [BufferController] Buffer Cleared: \(reason)")
    onBufferClear?(reason)
  }
}