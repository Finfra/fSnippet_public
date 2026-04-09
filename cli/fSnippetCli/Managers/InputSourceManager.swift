import Foundation
import Carbon

/// CL038: 입력 소스 관리자
/// 입력 소스 간의 동적 전환을 처리합니다.
class InputSourceManager {
    static let shared = InputSourceManager()
    
    struct InputSourceInfo: Identifiable, Hashable {
        let id: String
        let name: String
    }
    
    private init() {}
    
    private var savedInputSource: TISInputSource?
    
    /// 활성화된 모든 입력 소스 가져오기 (설정 피커용)
    func getAvailableInputSources() -> [InputSourceInfo] {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        
        var results: [InputSourceInfo] = []
        
        for source in sources {
            // 카테고리 가져오기 (키보드 입력 소스여야 함)
            let categoryPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory)
            if let categoryPtr = categoryPtr,
               let category = Unmanaged<CFString>.fromOpaque(categoryPtr).takeUnretainedValue() as CFString as String?,
               category == (kTISCategoryKeyboardInputSource as String) {
                
                // ID 가져오기
                guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
                      let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as CFString as String? else { continue }
                
                // 지역화된 이름 가져오기
                var name = id
                if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
                   let localizedName = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as CFString as String? {
                    name = localizedName
                }
                
                // 필요한 경우 일부 내부 입력을 필터링하지만, 현재는 모든 키보드 입력을 표시함
                // 특히 선택 가능한지 확인함
                let isSelectable = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable)
                if let isSelectable = isSelectable,
                   Unmanaged<CFBoolean>.fromOpaque(isSelectable).takeUnretainedValue() == kCFBooleanTrue {
                    results.append(InputSourceInfo(id: id, name: name))
                }
            }
        }
        
        return results.sorted { $0.name < $1.name }
    }
    
    /// 일반 ID를 사용하여 강제 입력 소스 설정 적용
    func applyForceInputSource() {
        let forceOptionRaw = PreferencesManager.shared.string(forKey: "history.forceInputSource", defaultValue: "keep")
        
        logV("🌐 ⌨️ [InputSourceManager] Applying Force Input Source. Setting: '\(forceOptionRaw)'")

        if forceOptionRaw == "keep" {
            logV("🌐 ⌨️ [InputSourceManager] Option is 'keep'. No action taken.")
            return
        }
        
        // 전환 전 현재 입력 소스 저장 (이미 저장되지 않은 경우)
        if savedInputSource == nil {
            saveCurrentInputSource()
        }
        
        // ID로 정확한 소스 찾기 시도
        if let source = findInputSource(id: forceOptionRaw) {
             selectInputSource(source)
             logV("🌐 ⌨️ [InputSourceManager] Switched to forced input source: \(forceOptionRaw)")
             return
        }
        
        // 오래된 "english"/"korean" 값에 대한 하위 호환성 (마이그레이션이 발생하지 않은 경우)
        if forceOptionRaw == "english" {
            switchToEnglish()
            return
        } else if forceOptionRaw == "korean" {
            switchToKorean()
            return
        }
        
        logE("🌐 ❌ [InputSourceManager] Could not find input source with ID: \(forceOptionRaw)")
    }
    
    /// 현재 입력 소스 저장
    func saveCurrentInputSource() {
        let currentSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        savedInputSource = currentSource
        logD("🌐 ⌨️ [InputSourceManager] Saved input source: \(currentSource)")
    }
    
    /// 이전에 저장된 입력 소스 복원
    func restoreInputSource() {
        guard let saved = savedInputSource else {
            logV("🌐 ⌨️ [InputSourceManager] No saved input source to restore")
            return
        }
        
        selectInputSource(saved)
        savedInputSource = nil
        logD("🌐 ⌨️ [InputSourceManager] Restored input source")
    }
    
    // MARK: - 레거시 헬퍼 (폴백용으로 유지)
    
    /// 영어 입력 소스로 전환 (폴백 로직)
    func switchToEnglish() {
        if let source = findInputSource(id: "com.apple.keylayout.ABC") ?? findInputSource(id: "com.apple.keylayout.US") {
            selectInputSource(source)
            return
        }
        if let source = findInputSourceByLanguage("en") {
             selectInputSource(source)
             return
        }
        if let source = findAsciiCapableInputSource() {
            selectInputSource(source)
        }
    }
    
    func switchToKorean() {
        let koreanIDs = [
            "com.apple.inputmethod.Korean.2SetKorean",
            "com.apple.inputmethod.Korean"
        ]
        for id in koreanIDs {
            if let source = findInputSource(id: id) {
                selectInputSource(source)
                return
            }
        }
        if let source = findInputSourceByLanguage("ko") {
            selectInputSource(source)
        }
    }
    
    // MARK: - 내부 헬퍼
    
    private func findInputSource(id: String) -> TISInputSource? {
        let conditions = [
            kTISPropertyInputSourceID: id
        ] as CFDictionary
        
        guard let sources = TISCreateInputSourceList(conditions, false)?.takeRetainedValue() as? [TISInputSource],
              let source = sources.first else {
            return nil
        }
        return source
    }
    
    private func findAsciiCapableInputSource() -> TISInputSource? {
         let conditions = [
            kTISPropertyInputSourceIsASCIICapable: true,
            kTISPropertyInputSourceType: kTISTypeKeyboardLayout as CFString
        ] as CFDictionary
        
        guard let sources = TISCreateInputSourceList(conditions, false)?.takeRetainedValue() as? [TISInputSource],
              let source = sources.first else {
            return nil
        }
        return source
    }
    
    private func findInputSourceByLanguage(_ languageCode: String) -> TISInputSource? {
         guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        
        for source in sources {
            let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages)
            if let ptr = ptr {
                if let languages = Unmanaged<NSArray>.fromOpaque(ptr).takeUnretainedValue() as? [String] {
                    if languages.contains(languageCode) {
                        return source
                    }
                }
            }
        }
        return nil
    }
    
    private func selectInputSource(_ source: TISInputSource) {
        let currentStatus = TISSelectInputSource(source)
        if currentStatus != noErr {
            logE("🌐 ❌ [InputSourceManager] Failed to switch input source. Status: \(currentStatus)")
        }
    }
}
