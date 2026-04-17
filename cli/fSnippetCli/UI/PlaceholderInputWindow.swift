import Cocoa
import Foundation
import SwiftUI

// MARK: - Data Models

struct PlaceholderData: Equatable {
    let name: String
    let defaultValue: String?
    let index: Int  // 원본 텍스트에서의 위치

    init(name: String, defaultValue: String? = nil, index: Int = 0) {
        self.name = name
        self.defaultValue = defaultValue
        self.index = index
    }
}

struct PlaceholderResult: Equatable {
    let name: String
    let value: String

    init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

// MARK: - SwiftUI View

// MARK: - SwiftUI View

enum FocusableComponent: Hashable {
    case field(Int)
    case confirmButton
    case cancelButton
}

struct PlaceholderInputView: View {
    @ObservedObject var viewModel: PlaceholderInputViewModel
    @State private var isVisible: Bool = true
    @FocusState private var focusedComponent: FocusableComponent?  // ✅ 커스텀 포커스 상태

    var body: some View {
        mainContent
            .padding(20)
            .frame(width: 400)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.9)
            .animation(.easeInOut(duration: 0.1), value: isVisible)
            // ✅ ESC 키 감지하여 닫기
            .onExitCommand {
                logV("🌫️ [PlaceholderInputView] ESC 키 입력 감지")
                viewModel.cancel()
            }
            .accessibilityIdentifier("PlaceholderInputView")
            .onAppear {
                logD("🌫️ 플레이스홀더 입력창 표시됨")
                // ✅ 첫 번째 필드에 포커스
                focusedComponent = .field(0)
            }
            .onKeyPress(keys: [.tab]) { press in
                handleTabKey(isShiftPressed: press.modifiers.contains(EventModifiers.shift))
                return .handled
            }
            // ✅ Issue 346: 포커스 상태를 ViewModel에 동기화
            .onChange(of: focusedComponent) { _, newValue in
                if case .field(let index) = newValue {
                    viewModel.currentFocusedIndex = index
                }
            }
        // 이전 SwiftUI 지원(macOS 12+)을 위해 onChange(of:perform:) 서명이 약간 다르지만 일반적으로 작동함.
        // 엄격한 2-arg인 경우 .onChange(of: focusedComponent) { newValue in ... } 사용
    }

    // ✅ 탭 키 핸들링 로직 (Fields <-> Confirm)
    private func handleTabKey(isShiftPressed: Bool) {
        guard !viewModel.placeholders.isEmpty else { return }

        let lastIndex = viewModel.placeholders.count - 1

        if isShiftPressed {
            // 역방향: Field(0) -> Confirm -> Field(Last)
            switch focusedComponent {
            case .field(let index):
                if index > 0 {
                    focusedComponent = .field(index - 1)
                } else {
                    focusedComponent = .confirmButton  // 0번에서 뒤로가면 Confirm
                }
            case .confirmButton:
                focusedComponent = .field(lastIndex)
            case .cancelButton:
                focusedComponent = .confirmButton
            case nil:
                focusedComponent = .field(lastIndex)
            }
        } else {
            // 정방향: Field(Last) -> Confirm -> Field(0)
            switch focusedComponent {
            case .field(let index):
                if index < lastIndex {
                    focusedComponent = .field(index + 1)
                } else {
                    focusedComponent = .confirmButton  // 마지막 필드 다음은 Confirm
                }
            case .confirmButton:
                focusedComponent = .field(0)  // Confirm 다음은 다시 첫 번째 필드
            case .cancelButton:
                focusedComponent = .field(0)
            case nil:
                focusedComponent = .field(0)
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 16) {
            headerView
            previewView
            inputFieldsView
            buttonView
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text(L10n("placeholder.window.title"))
                .font(.headline)
                .foregroundColor(.primary)

            // ✅ Issue 346: 클립보드 기록 버튼
            Button(action: {
                viewModel.openHistory()
            }) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .instantTooltip(L10n("placeholder.help.history"))
            .focusable(false)

            Spacer()

            Button(action: {
                viewModel.cancel()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .focusable(false)  // ✅ X 버튼은 탭 포커스에서 제외
        }
    }

    @ViewBuilder
    private var inputFieldsView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.placeholders.enumerated()), id: \.offset) {
                    index, placeholder in
                    PlaceholderInputFieldView(
                        placeholder: placeholder,
                        text: Binding(
                            get: {
                                viewModel.results[placeholder.name] ?? placeholder.defaultValue
                                    ?? ""
                            },
                            set: {
                                viewModel.results[placeholder.name] = $0
                                viewModel.generatePreview()
                            }
                        ),
                        fieldIndex: index,
                        focusedComponent: $focusedComponent,  // ✅ 변경된 바인딩 전달
                        onSubmit: {
                            viewModel.confirm()
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 200)
        // ✅ Issue 346: Cmd+V 지원 (키보드 단축키)
        // 참고: 메뉴가 올바르면 TextField는 기본적으로 붙여넣기를 처리함.
        // 하지만 포커스/메뉴가 까다로운 경우 명시적 핸들러를 추가함.
        // .command 수식어와 함께 "v" 사용.
        .background(
            Button("Paste") {
                viewModel.pasteFromClipboard()
            }
            .keyboardShortcut("v", modifiers: .command)
            .opacity(0)
        )
    }

    @ViewBuilder
    private var buttonView: some View {
        HStack(spacing: 12) {
            Button(L10n("placeholder.button.cancel")) {
                viewModel.cancel()
            }
            .focused($focusedComponent, equals: .cancelButton)  // ✅ 포커스 연결
            .keyboardShortcut(.cancelAction)  // ESC
            .focusable(false)  // 탭 사이클에서 제외 (ESC 사용 권장)

            Button(L10n("placeholder.button.confirm")) {
                viewModel.confirm()
            }
            .buttonStyle(.borderedProminent)
            .focused($focusedComponent, equals: .confirmButton)  // ✅ 포커스 연결
            .keyboardShortcut(.defaultAction)  // Enter
            .focusable(true)  // ✅ 탭 포커스 가능하도록 설정
            // ✅ Issue: 명시적 시각적 포커스 표시기
            // 전체 키보드 접근이 꺼져 있으면 시스템 포커스 링이 숨겨질 수 있음.
            // 커스텀 포커스 상태가 일치할 때 시각적 신호를 강제함.
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.blue, lineWidth: (focusedComponent == .confirmButton) ? 3 : 0)
                    .padding(-2)
            )
        }
    }

    @ViewBuilder
    private var previewView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n("placeholder.label.preview"))
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                Text(viewModel.previewText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 80)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
        }
    }
}

// MARK: - Individual Input Field Component

struct PlaceholderInputFieldView: View {
    let placeholder: PlaceholderData
    @Binding var text: String
    let fieldIndex: Int
    var focusedComponent: FocusState<FocusableComponent?>.Binding  // ✅ 변경된 바인딩 타입
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(placeholder.name)
                .font(.caption)
                .foregroundColor(.secondary)

            // ✅ Issue655: RoundedBorderTextFieldStyle은 foregroundColor를 무시하는 macOS 버그가 있음
            // PlainTextFieldStyle + 수동 배경/테두리로 우회
            TextField(
                placeholder.defaultValue ?? "",
                text: $text
            )
            .textFieldStyle(PlainTextFieldStyle())
            .foregroundColor(.primary)  // ✅ 텍스트 색상 (PlainStyle에서는 작동함)
            .accentColor(.blue)  // ✅ 커서 색상
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(NSColor.secondaryLabelColor), lineWidth: 1.5)
            )
            .focused(focusedComponent, equals: .field(fieldIndex))  // ✅ 포커스 연결
            .onSubmit {
                onSubmit()
            }
        }
    }
}

// MARK: - ViewModel

class PlaceholderInputViewModel: ObservableObject {
    @Published var placeholders: [PlaceholderData] = []
    @Published var results: [String: String] = [:]
    @Published var previewText: AttributedString = AttributedString("")

    // ✅ 삽입을 위한 포커스된 필드 인덱스 추적
    var currentFocusedIndex: Int = 0

    private var templateContent: String = ""
    private var previewSegments: [PreviewSegment] = []

    private struct PreviewSegment {
        let isPlaceholder: Bool
        let content: String  // text or placeholder name
        let defaultValue: String?
    }

    private var onCompletion: (([PlaceholderResult]) -> Void)?
    private var onCancel: (() -> Void)?

    func setup(
        placeholders: [PlaceholderData],
        templateContent: String,
        onCompletion: @escaping ([PlaceholderResult]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.placeholders = placeholders
        self.templateContent = templateContent
        self.onCompletion = onCompletion
        self.onCancel = onCancel

        // Issue792: 캐시된 값 → 기본값 → 빈 문자열 우선순위로 초기화
        self.results = [:]
        for placeholder in placeholders {
            let cachedValue = PlaceholderCache.shared.getValue(for: placeholder.name)
            self.results[placeholder.name] = cachedValue ?? placeholder.defaultValue ?? ""
        }

        logD("🌫️ [PlaceholderInputViewModel] 설정 완료 - placeholders: \(placeholders.count)개")

        // 템플릿 파싱 및 초기 미리보기 생성
        parseTemplate()
        generatePreview()
    }

    // ... (parseTemplate & generatePreview omitted, keep existing) ...

    // ✅ Issue 346: 기록 뷰어 열기
    func openHistory() {
        HistoryViewerManager.shared.show(onSelection: { [weak self] selectedText in
            self?.insertTextIntoFocusedField(selectedText)
        })
    }

    // ✅ Issue 346: 붙여넣기 구현
    func pasteFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string) {
            insertTextIntoFocusedField(string)
        }
    }

    // ✅ 삽입 로직
    private func insertTextIntoFocusedField(_ text: String) {
        guard currentFocusedIndex < placeholders.count else { return }

        let placeholder = placeholders[currentFocusedIndex]
        let currentText = results[placeholder.name] ?? ""

        // 현재는 추가(Append) (NSTextView에 직접 접근하지 않고 커서 위치에 삽입하기는 어려움)
        // 이상적으로는 커서 위치에 삽입해야 하지만, 대체보다는 추가가 더 안전함.
        let newText = currentText + text

        results[placeholder.name] = newText
        generatePreview()

        logD(
            "🌫️ [PlaceholderInputViewModel] Inserted text into field \(currentFocusedIndex) ('\(placeholder.name)')"
        )
    }

    private func parseTemplate() {
        previewSegments = []
        let pattern = #"\{\{([\w\s]+)(?::([\w\s]*))?\}\}"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            previewSegments = [
                .init(isPlaceholder: false, content: templateContent, defaultValue: nil)
            ]
            return
        }

        let nsString = templateContent as NSString
        let matches = regex.matches(
            in: templateContent, range: NSRange(location: 0, length: nsString.length))

        var currentIndex = 0

        for match in matches {
            // Placeholder 앞의 텍스트 추가
            let rangeBefore = NSRange(
                location: currentIndex, length: match.range.location - currentIndex)
            if rangeBefore.length > 0 {
                previewSegments.append(
                    .init(
                        isPlaceholder: false, content: nsString.substring(with: rangeBefore),
                        defaultValue: nil))
            }

            // Placeholder 정보 추출
            if let nameRange = Range(match.range(at: 1), in: templateContent) {
                let name = String(templateContent[nameRange]).trimmingCharacters(
                    in: .whitespacesAndNewlines)
                var defaultValue: String? = nil

                if match.numberOfRanges > 2,
                    let range = Range(match.range(at: 2), in: templateContent)
                {
                    defaultValue = String(templateContent[range]).trimmingCharacters(
                        in: .whitespacesAndNewlines)
                }

                previewSegments.append(
                    .init(isPlaceholder: true, content: name, defaultValue: defaultValue))
            }

            currentIndex = match.range.location + match.range.length
        }

        // 마지막 남은 텍스트 추가
        if currentIndex < nsString.length {
            let rangeAfter = NSRange(location: currentIndex, length: nsString.length - currentIndex)
            previewSegments.append(
                .init(
                    isPlaceholder: false, content: nsString.substring(with: rangeAfter),
                    defaultValue: nil))
        }
    }

    func generatePreview() {
        var attrStr = AttributedString("")

        for segment in previewSegments {
            if segment.isPlaceholder {
                let inputValue = results[segment.content] ?? ""

                if !inputValue.isEmpty {
                    // 1. 입력값이 있는 경우
                    var segmentAttr = AttributedString(inputValue)
                    segmentAttr.foregroundColor = .blue  // 강조 색상
                    segmentAttr.font = .body.bold()  // 굵게 표시
                    attrStr.append(segmentAttr)
                } else if let defaultValue = segment.defaultValue, !defaultValue.isEmpty {
                    // 2. 기본값이 있는 경우
                    var segmentAttr = AttributedString(defaultValue)
                    segmentAttr.foregroundColor = .blue
                    segmentAttr.font = .body.bold()
                    attrStr.append(segmentAttr)
                } else {
                    // 3. 둘 다 없는 경우 - 플레이스홀더 태그 표시
                    var segmentAttr = AttributedString("{{\(segment.content)}}")
                    segmentAttr.foregroundColor = .secondary  // 연하게 표시
                    attrStr.append(segmentAttr)
                }
            } else {
                attrStr.append(AttributedString(segment.content))
            }
        }

        self.previewText = attrStr
    }

    // results 변경 시 미리보기 업데이트를 위해 Binding custom setter가 필요할 수 있으나,
    // View에서 Binding을 set 할 때 objectWillChange가 호출되므로,
    // didSet 혹은 published property 변경 감지 로직이 필요함.
    // 간단히 results didSet은 동작하지 않음 (Struct in Class).
    // View의 Binding Set에서 updatePreview를 호출하도록 하거나,
    // results를 감시해야 함. 가장 쉬운 방법은 View에서 set 할 때 results 업데이트 후 generatePreview 호출.

    func confirm() {
        let placeholderResults = placeholders.map { placeholder in
            PlaceholderResult(
                name: placeholder.name,
                value: results[placeholder.name] ?? placeholder.defaultValue ?? ""
            )
        }

        // Issue792: 입력값을 캐시에 저장
        PlaceholderCache.shared.saveResults(placeholderResults)

        logV("🌫️ 플레이스홀더 입력 완료 - 결과: \(placeholderResults.count)개")
        onCompletion?(placeholderResults)
    }

    func cancel() {
        logV("🌫️ 플레이스홀더 입력 취소")
        onCancel?()
    }
}

// MARK: - Window Controller

class PlaceholderInputWindow: NSObject, NSWindowDelegate {

    // MARK: - Properties

    private var window: NSWindow?
    private var hostingView: NSHostingView<PlaceholderInputView>?
    private let viewModel = PlaceholderInputViewModel()

    // MARK: - Initialization

    override init() {
        super.init()
        setupWindow()
        logV("🌫️ [PlaceholderInputWindow] 초기화 완료 - 화면 중앙 위치")
    }

    // MARK: - Public Methods

    func showInput(
        with placeholders: [PlaceholderData],
        templateContent: String,
        referenceFrame: NSRect? = nil,
        onCompletion: @escaping ([PlaceholderResult]) -> Void
    ) {
        logV("🌫️ [PlaceholderInputWindow] showInput 호출 - placeholders: \(placeholders.count)개")

        // ViewModel 설정
        viewModel.setup(
            placeholders: placeholders,
            templateContent: templateContent,
            onCompletion: { [weak self] results in
                logV("🌫️ [PlaceholderInputWindow] onCompletion 호출 - 결과: \(results.count)개")
                self?.hideWindow()
                onCompletion(results)
            },
            onCancel: { [weak self] in
                logV("🌫️ [PlaceholderInputWindow] onCancel 호출 - 창 닫기 및 앱 숨기기 (포커스 복구)")
                self?.hideWindow()
                // ✅ Issue 328 개선: 타이밍 이슈 방지를 위해 지연 실행 및 명시적 로그 추가
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    logV("🌫️ [PlaceholderInputWindow] 앱 숨기기 실행 (NSApp.hide)")
                    NSApp.hide(nil)
                }

                // ✅ 취소 시에도 onCompletion을 빈 배열로 호출하여 TextReplacer가 isReplacing 상태를 해제하게 함
                onCompletion([])
            }
        )

        logV("🌫️ [PlaceholderInputWindow] ViewModel 설정 완료, 윈도우 표시 시작")

        // 반드시 메인 큐에서 윈도우 표시 (Issue796: sync → async 변경으로 블로킹 해소)
        if Thread.isMainThread {
            logV("🌫️ [PlaceholderInputWindow] 메인 스레드에서 직접 윈도우 표시")
            showWindow(referenceFrame: referenceFrame)
        } else {
            logV("🌫️ [PlaceholderInputWindow] 백그라운드 스레드에서 메인 큐로 디스패치")
            DispatchQueue.main.async { [weak self] in
                self?.showWindow(referenceFrame: referenceFrame)
            }
        }

        logV("🌫️ 플레이스홀더 입력창 표시 완료")
    }

    func isVisible() -> Bool {
        return window?.isVisible ?? false
    }

    // MARK: - Private Methods

    private func setupWindow() {
        // SwiftUI 뷰 생성
        let placeholderInputView = PlaceholderInputView(viewModel: viewModel)
        hostingView = NSHostingView(rootView: placeholderInputView)

        // Issue796: NSPanel로 변경 — 앱 활성화(NSApp.activate) 없이 키 윈도우가 될 수 있음
        // 스니펫 팝업/클립보드 팝업과 동일하게 설정창 등 다른 윈도우를 노출시키지 않음
        // CommandHandlingPanel: Cmd+A(전체선택), Cmd+C/V/X 등 편집 단축키를 TextField로 전달
        let panel = CommandHandlingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window = panel

        guard let window = window, let hostingView = hostingView else {
            logE("🌫️ ❌ 플레이스홀더 윈도우 초기화 실패")
            return
        }

        // 윈도우 속성 설정
        window.contentView = hostingView
        window.title = L10n("placeholder.window.title")
        window.isReleasedWhenClosed = false
        // Issue796: .floating 레벨로 다른 윈도우 위에 표시 (앱 활성화 없이)
        window.level = .floating
        window.hasShadow = true
        window.isMovable = true
        window.hidesOnDeactivate = false
        window.acceptsMouseMovedEvents = true
        window.isOpaque = true
        // Issue796: NSPanel이 키 윈도우가 될 수 있도록 설정
        panel.becomesKeyOnlyIfNeeded = false  // 항상 키 윈도우가 됨
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // 화면 중앙 위치 설정
        window.center()

        // XCUITest 식별자 설정
        window.setAccessibilityIdentifier("PlaceholderInputWindow")

        // 초기에는 숨김 상태
        window.orderOut(nil)

        logV("🌫️ [PlaceholderInputWindow] 윈도우 설정 완료 - NSPanel (nonactivatingPanel)")
    }

    private func showWindow(referenceFrame: NSRect? = nil) {
        logV("🌫️ [PlaceholderInputWindow] showWindow 시작")
        guard let window = window else {
            logE("🌫️ [PlaceholderInputWindow] 윈도우가 nil임!")
            return
        }

        // Issue796: 위치 설정 후 단일 활성화 (showWindow 끝에서 수행)
        if let refFrame = referenceFrame {
            logV("🌫️ [PlaceholderInputWindow] Reference Frame Received: \(refFrame)")

            // 1. 기준 프레임이 있는 스크린 찾기 (중심점 기준)
            let refCenter = NSPoint(x: refFrame.midX, y: refFrame.midY)
            var targetScreen: NSScreen? = nil

            for screen in NSScreen.screens {
                if NSPointInRect(refCenter, screen.frame) {
                    targetScreen = screen
                    break
                }
            }

            // 못 찾으면 intersect로 재시도
            if targetScreen == nil {
                for screen in NSScreen.screens {
                    if screen.frame.intersects(refFrame) {
                        targetScreen = screen
                        break
                    }
                }
            }

            // 그래도 없으면 메인 스크린
            let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first!
            logV("🌫️ Target Screen: \(screen.localizedName) (Frame: \(screen.frame))")

            // 2. 윈도우 크기
            let windowSize = window.frame.size

            // 3. 기준 프레임의 중앙에 위치 계산
            // 기준점: refFrame의 중앙 - (windowWidth/2, windowHeight/2)
            var newOriginX = refFrame.midX - (windowSize.width / 2)
            var newOriginY = refFrame.midY - (windowSize.height / 2)

            // 4. 화면 밖으로 나가지 않도록 Clamp
            let screenRect = screen.visibleFrame

            // X축 Clamp
            if newOriginX < screenRect.minX { newOriginX = screenRect.minX }
            if newOriginX + windowSize.width > screenRect.maxX {
                newOriginX = screenRect.maxX - windowSize.width
            }

            // Y축 Clamp
            if newOriginY < screenRect.minY { newOriginY = screenRect.minY }
            if newOriginY + windowSize.height > screenRect.maxY {
                newOriginY = screenRect.maxY - windowSize.height
            }

            logV("🌫️ Calculated Position: (\(newOriginX), \(newOriginY))")

            window.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))

        } else {
            // 기준 프레임 없음 - 2안: 마우스 위치 기준 (Issue233 강화)
            // 사용자가 방금 클릭했거나 선택했을 위치 근처가 안전함

            let mouseLoc = NSEvent.mouseLocation
            logV("🌫️️ No Reference Frame - Fallback to Mouse Location: \(mouseLoc)")

            // 마우스가 위치한 스크린 찾기
            var targetScreen: NSScreen? = nil
            for screen in NSScreen.screens {
                if NSMouseInRect(mouseLoc, screen.frame, false) {
                    targetScreen = screen
                    break
                }
            }

            let screen = targetScreen ?? NSScreen.main ?? NSScreen.screens.first!
            logV("🌫️ Fallback Screen: \(screen.localizedName)")

            let windowSize = window.frame.size
            let screenRect = screen.visibleFrame

            // 마우스 위치에서 약간 아래/오른쪽으로 오프셋 (커서 가리지 않게)
            var newOriginX = mouseLoc.x - (windowSize.width / 2)  // 가로는 중앙
            var newOriginY = mouseLoc.y - windowSize.height - 20  // 세로는 마우스 아래

            // Clamp
            if newOriginX < screenRect.minX { newOriginX = screenRect.minX }
            if newOriginX + windowSize.width > screenRect.maxX {
                newOriginX = screenRect.maxX - windowSize.width
            }

            if newOriginY < screenRect.minY { newOriginY = screenRect.minY }  // 너무 아래면
            if newOriginY + windowSize.height > screenRect.maxY {
                newOriginY = screenRect.maxY - windowSize.height
            }  // 너무 위면

            // 만약 마우스 아래 공간이 부족해서 위로 튕겼는데, 그것도 이상하면 그냥 화면 중앙
            if newOriginY < screenRect.minY {
                newOriginY = screenRect.midY - (windowSize.height / 2)
            }

            window.setFrameOrigin(NSPoint(x: newOriginX, y: newOriginY))
        }

        // Issue796: NSPanel + nonactivatingPanel이므로 NSApp.activate 불필요
        // NSApp.activate를 호출하면 설정창 등 숨겨진 윈도우가 함께 노출됨
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        // 단일 지연 포커스: SwiftUI가 레이아웃을 완료한 후 텍스트 필드에 포커스
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, let window = self.window else { return }

            // 이미 텍스트 필드에 포커스가 있으면 생략
            if let firstResponder = window.firstResponder, firstResponder is NSTextView {
                logV("🌫️ [PlaceholderInputWindow] 포커스가 이미 NSTextView에 설정됨")
                return
            }

            // 텍스트 필드에 직접 포커스
            self.forceTextFieldFocus()
        }

        logV(
            "🌫️ [PlaceholderInputWindow] 윈도우 상태 - visible: \(window.isVisible), isKey: \(window.isKeyWindow), level: \(window.level.rawValue)"
        )
    }

    private func hideWindow() {
        guard let window = window else { return }

        window.orderOut(nil)
        logV("🌫️ [PlaceholderInputWindow] 윈도우 숨김 완료")
    }

    /// 첫 번째 텍스트 필드에 강제로 포커스를 설정하는 메서드
    private func forceTextFieldFocus() {
        guard let window = window, let hostingView = hostingView else {
            logE("🌫️ [PlaceholderInputWindow] 윈도우 또는 호스팅 뷰가 nil임")
            return
        }

        logV("🌫️ [PlaceholderInputWindow] 텍스트 필드 직접 포커스 설정 시작")

        // SwiftUI 뷰 내부의 텍스트 필드를 찾아서 포커스 설정
        let textField = findFirstTextField(in: hostingView)
        if let textField = textField {
            let success = window.makeFirstResponder(textField)
            logV("🌫️ [PlaceholderInputWindow] 첫 번째 텍스트 필드 포커스 설정 결과: \(success)")
        } else {
            logW("🌫️ [PlaceholderInputWindow] 첫 번째 텍스트 필드를 찾을 수 없음")

            // 차선책: contentView에 포커스 설정
            window.makeFirstResponder(hostingView)
            logV("🌫️ [PlaceholderInputWindow] 호스팅 뷰에 포커스 설정 완료")
        }
    }

    /// 뷰 계층에서 첫 번째 NSTextField를 찾는 재귀 메서드
    private func findFirstTextField(in view: NSView) -> NSTextField? {
        // 현재 뷰가 NSTextField인지 확인
        if let textField = view as? NSTextField {
            return textField
        }

        // 자식 뷰들을 재귀적으로 탐색
        for subview in view.subviews {
            if let textField = findFirstTextField(in: subview) {
                return textField
            }
        }

        return nil
    }

    deinit {
        window?.orderOut(nil)
        window = nil
        hostingView = nil
        logV("🌫️ [PlaceholderInputWindow] 정리 완료")
    }

    // MARK: - NSWindowDelegate Methods

    func windowDidResignKey(_ notification: Notification) {
        // 윈도우가 키 윈도우 상태를 잃었을 때 (다른 앱으로 포커스 이동 시)
        logV("🌫️ [PlaceholderInputWindow] 윈도우가 키 상태를 잃음 - 다른 앱으로 포커스 이동")

        // ✅ Issue: KeyEventMonitor에게 우회를 비활성화하도록 알림
        NotificationCenter.default.post(
            name: NSNotification.Name("fSnippetPlaceholderWindowDidResignActive"), object: nil)

        // 약간의 지연 후 창 자동 닫기 (사용자가 확인/엔터 누르지 않은 경우)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            // ✅ Issue262: 앱이 여전히 활성 상태라면(예: 내부 포커스 이동, Tab 키 등) 창을 닫지 않음
            if NSApp.isActive {
                logV("🌫️ [PlaceholderInputWindow] 앱이 활성 상태이므로 창 닫기 취소 (내부 포커스 이동 추정)")
                return
            }

            if let self = self, let window = self.window, window.isVisible {
                logV("🌫️ [PlaceholderInputWindow] 다른 앱 포커스로 인한 자동 창 닫기")
                self.viewModel.cancel()  // 취소 처리로 창 닫기
            }
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // 윈도우가 키 윈도우가 되었을 때
        logV("🌫️ [PlaceholderInputWindow] 윈도우가 키 상태가 됨")

        // ✅ Issue: Notify KeyEventMonitor to enable bypass (prevent Tab/Shortcut interference)
        NotificationCenter.default.post(
            name: NSNotification.Name("fSnippetPlaceholderWindowDidBecomeActive"), object: nil)
    }
}
