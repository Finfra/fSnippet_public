import Foundation

/// 스니펫 약어(Abbreviation) 계산 및 관련 로직을 전담하는 클래스
/// 순수 로직(Pure Logic) 위주로 구성되어야 하며, 파일 시스템 접근은 최소화하거나 의존성 주입을 통해 해결합니다.
class AbbreviationCalculator {
  static let shared = AbbreviationCalculator()

  // MARK: - Core Calculation Logic

  /// 파일에서 abbreviation 키 추출 (폴더첫글자 + 파일명 + 특수기호)
  func getAbbreviation(for file: URL) -> String {
    let fileName = file.lastPathComponent
    let folderName = file.deletingLastPathComponent().lastPathComponent
    let baseFileName = file.deletingPathExtension().lastPathComponent

    // 숨겨진 파일이나 점으로 시작하는 파일 제외
    if fileName.hasPrefix(".") {
      return ""
    }

    return calcAbbreviation(folderName: folderName, baseFileName: baseFileName, file: file)
  }

  /// 핵심 약어 계산 로직 (SnippetFileManager에서 이동됨)
  func calcAbbreviation(folderName: String, baseFileName: String, file: URL? = nil) -> String {
    // let fileName = ... (Removed unused variable)
    // let filePath = file?.path ?? "Virtual Path" // Unused in pure logic

    var keyword: String
    var useFolderPrefix: Bool
    var useRawAbbreviation = false

    // Issue54: Alfred 폴더인지 확인 (_, _FUNDAMENTAL, _alfred 등으로 시작)
    let isAlfredFolder = folderName.hasPrefix("_")

    // ✅ Issue34/401: 폴더 타입에 따른 규칙 적용 결정
    let shouldUseAlfredRules =
      isAlfredFolder || RuleManager.shared.getRule(for: folderName) != nil

    // Issue 573: _로 끝나는 파일의 Initcap 로직 강제 적용
    let isInitcapFile =
      baseFileName.contains("===")
      && (baseFileName.hasSuffix("_") || baseFileName.hasSuffix("{underbar}"))

    if baseFileName.contains("===") {
      let parts = baseFileName.split(
        separator: "===", maxSplits: 1, omittingEmptySubsequences: false)
      let beforePart = parts.count > 0 ? String(parts[0]) : ""
      let afterPart = parts.count > 1 ? String(parts[1]) : ""

      if beforePart.isEmpty {
        // Issue68/73/75: ===name.txt 형식인 경우
        if !afterPart.isEmpty {
          // Explicit Empty Keyword -> Use Folder Prefix Only
          let extractedPrefix = FileUtilities.extractCapitalLetters(from: folderName)

          // Default: Use Folder Prefix (Lowercase)
          keyword = ""
          useFolderPrefix = true

          // Check for Initcap Suffix (_ or {underbar})
          let hasInitcapSuffix =
            afterPart.hasSuffix("_") || afterPart.hasSuffix("{underbar}")

          if hasInitcapSuffix {
            // Initcap: Uppercase first letter of derived prefix
            let initcapPrefix =
              extractedPrefix.prefix(1).uppercased() + extractedPrefix.dropFirst()
            keyword = initcapPrefix
            useFolderPrefix = false
          }
        } else {
          // afterPart가 빈 경우: 빈 키워드 + folderPrefix 사용
          keyword = ""
          useFolderPrefix = true
        }

        // 🚨 Issue55: Alfred 폴더의 빈 키워드 검증
        // 계산기 역할에서는 빈 문자열 반환 (Validation은 Repository 또는 호출자 책임)
        if isAlfredFolder, RuleManager.shared.getRule(for: folderName) != nil {
          if file != nil {
            // 실제 파일이 존재하는 경우, 이 로직은 에러 상황임.
            // 하지만 Calculator는 계산만 수행하므로 빈 값 반환.
            // 호출자(Repository)가 빈 값을 보고 파일 삭제 등의 조치를 취해야 함?
            // 또는 기존 로직대로라면 여기서 빈 값을 반환하면 스니펫 맵에 등록되지 않음.
            return ""
          }
          return ""
        }
      } else {
        // keyword===name.txt 형식인 경우
        var processedKeyword = beforePart
        processedKeyword = replaceSpecialCharacters(processedKeyword)
        keyword = processedKeyword

        useFolderPrefix = !isAlfredFolder

        if isInitcapFile {
          useFolderPrefix = false
          if keyword.hasSuffix("_") {
            keyword = String(keyword.dropLast())
          }
        }

        // Issue44/46: === 앞부분이 이미 완성된 abbreviation인지 확인
        if shouldUseAlfredRules, let rule = RuleManager.shared.getRule(for: folderName) {
          if !rule.prefix.isEmpty && keyword.hasPrefix(rule.prefix)
            && !rule.suffix.isEmpty && keyword.hasSuffix(rule.suffix)
          {
            useRawAbbreviation = true
          } else if !rule.prefix.isEmpty && keyword.hasPrefix(rule.prefix)
            && !rule.suffix.isEmpty && !keyword.hasSuffix(rule.suffix)
          {
            keyword = keyword + rule.suffix
            useRawAbbreviation = true
          } else if rule.suffix == " " {
            useRawAbbreviation = true
          }
        }
      }
    } else {
      // 기존 방식: 파일명 전체를 키워드로 사용
      keyword = baseFileName
      keyword = replaceSpecialCharacters(keyword)  // Issue56
      useFolderPrefix = true
    }

    if useRawAbbreviation {
      return keyword
    }

    // Alfred 규칙 적용 로직
    if shouldUseAlfredRules, let rule = RuleManager.shared.getRule(for: folderName) {
      let settings = SettingsManager.shared.load()
      let useDefaultTrigger = rule.suffix.isEmpty && rule.prefix.isEmpty
      let triggerKey = useDefaultTrigger ? settings.defaultSymbol : ""

      let suffixToAdd = (isInitcapFile || rule.suffix == " ") ? "" : rule.suffix
      let textSuffix = sanitizeSuffix(suffixToAdd)

      var finalPrefix = rule.prefix

      if !isAlfredFolder {
        if useFolderPrefix {
          let autoPrefix = FileUtilities.extractCapitalLetters(from: folderName)
            .lowercased()

          if finalPrefix.isEmpty {
            finalPrefix = autoPrefix
          } else {
            if !autoPrefix.isEmpty && !finalPrefix.hasSuffix(autoPrefix) {
              finalPrefix = finalPrefix + autoPrefix
            }
          }
        }
      }

      let finalKeyword = keyword

      let finalAbbreviation = "\(finalPrefix)\(finalKeyword)\(textSuffix)\(triggerKey)"
      return finalAbbreviation

    } else {
      // 기본 방식
      let folderPrefix =
        useFolderPrefix
        ? FileUtilities.extractCapitalLetters(from: folderName).lowercased() : ""
      let settings = SettingsManager.shared.load()

      var rawSymbol = settings.folderSymbols[folderName.lowercased()] ?? ""
      if rawSymbol.isEmpty && !folderName.hasPrefix("_") {
        rawSymbol = settings.defaultSymbol
      }

      var symbol = (rawSymbol == "NumKey,") ? "" : rawSymbol

      if symbol.count > 1 && !symbol.hasPrefix("{") && !symbol.hasSuffix("}") {
        symbol = "{\(symbol)}"
      }

      let finalAbbreviation = "\(folderPrefix)\(keyword)\(symbol)"
      return finalAbbreviation
    }
  }

  /// 가상 새 스니펫에 대한 약어 계산 (UI 표시용)
  func calculateAbbreviation(folder: String, keyword: String, name: String) -> String {
    let safeName = SnippetItem.encodeKeyword(name)
    let safeKeyword = SnippetItem.encodeKeyword(keyword)

    var baseFileName = ""
    if safeName.isEmpty {
      baseFileName = safeKeyword
    } else {
      baseFileName = "\(safeKeyword)===\(safeName)"
    }

    return calcAbbreviation(folderName: folder, baseFileName: baseFileName, file: nil)
  }

  // MARK: - Helper Methods

  /// 특수 문자 치환 헬퍼
  private func replaceSpecialCharacters(_ input: String) -> String {
    var output = input
    output = output.replacingOccurrences(of: "{gt}", with: ">")
    output = output.replacingOccurrences(of: "{lt}", with: "<")
    output = output.replacingOccurrences(of: "{pipe}", with: "|")
    output = output.replacingOccurrences(of: "{caret}", with: "^")
    output = output.replacingOccurrences(of: "{underbar}", with: "_")
    output = output.replacingOccurrences(of: "{equal}", with: "=")
    output = output.replacingOccurrences(of: "{equals}", with: "=")
    output = output.replacingOccurrences(of: "{hash}", with: "#")
    output = output.replacingOccurrences(of: "{semicolon}", with: ";")
    output = output.replacingOccurrences(of: "{apostrophe}", with: "'")
    output = output.replacingOccurrences(of: "{backtick}", with: "`")
    output = output.replacingOccurrences(of: "{exclamation}", with: "!")
    output = output.replacingOccurrences(of: "{question}", with: "?")
    output = output.replacingOccurrences(of: "{tilde}", with: "~")
    output = output.replacingOccurrences(of: "{lbracket}", with: "[")
    output = output.replacingOccurrences(of: "{rbracket}", with: "]")
    output = output.replacingOccurrences(of: "{comma}", with: ",")
    return output
  }

  /// Suffix Sanitizer Helper
  func sanitizeSuffix(_ suffix: String) -> String {
    let lowerSymbol = suffix.lowercased()
    if lowerSymbol == "numkey," || lowerSymbol.hasPrefix("numkey")
      || lowerSymbol.hasPrefix("numlock") || lowerSymbol.hasPrefix("numclear")
      || lowerSymbol.hasPrefix("numenter") || lowerSymbol.hasPrefix("right_")
      || lowerSymbol.hasPrefix("left_") || lowerSymbol.hasPrefix("caps")
    {
      return ""
    }
    return suffix
  }

  /// 주어진 폴더, 이름, 키워드로 생성될 스니펫 파일의 전체 경로를 계산합니다. (SnippetFileManager.calculateDetailFilePath 대체)
  func calculateDetailFilePath(rootFolderURL: URL, folder: String, name: String, keyword: String)
    -> String
  {
    let folderURL = rootFolderURL.appendingPathComponent(folder)

    // 1. 키워드 및 이름 인코딩
    let safeName = SnippetItem.encodeKeyword(name)
    let safeKeyword = SnippetItem.encodeKeyword(keyword)

    // 2. 파일명 조합 규칙: keyword===name.txt
    let fileName: String
    if safeName.isEmpty {
      fileName = "\(safeKeyword).txt"
    } else {
      fileName = "\(safeKeyword)===\(safeName).txt"
    }

    return folderURL.appendingPathComponent(fileName).path
  }
}
