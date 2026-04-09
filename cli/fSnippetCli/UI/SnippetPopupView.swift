import Foundation
import SwiftUI

/// 리팩토링된 Snippet 선택 팝업 UI 컴포넌트
struct SnippetPopupView: View {
    @ObservedObject var viewModel: SnippetPopupViewModel
    @ObservedObject var settings = SettingsObservableObject.shared  // ✅ 설정 관찰
    @StateObject private var keyboardHandler: PopupKeyboardHandler

    // UI 상태
    @State private var updateTrigger: Bool = false
    @State private var searchText: String = ""  // ✅ 검색어 상태 추가
    @FocusState private var isSearchFocused: Bool  // ✅ 포커스 상태 추가

    // ✅ Issue 245: 중앙 집중식 상수 사용
    private let headerHeight: CGFloat = PopupUIConstants.headerHeight
    private let paddingHeight: CGFloat = PopupUIConstants.paddingHeight
    private let itemHeight: CGFloat = PopupUIConstants.rowHeight

    init(viewModel: SnippetPopupViewModel) {
        self.viewModel = viewModel
        self._keyboardHandler = StateObject(
            wrappedValue: PopupKeyboardHandler(
                maxIndex: { viewModel.snippets.count },
                onSelection: { index in
                    if index >= 0 && index < viewModel.snippets.count {
                        let selectedSnippet = viewModel.snippets[index]
                        viewModel.onSelection?(selectedSnippet)
                    }
                },
                onCancel: {
                    viewModel.onCancel?()
                },
                onEdit: {  // ✅ Issue9: Tab 키 편집/생성 → 유료 버전 전용 안내
                    logI("🗯️️ [PopupView] Tab Key Edit blocked - Paid version only")
                    PaidAppManager.shared.handlePaidFeature()
                }
            ))
    }

    // 표시할 스니펫 목록 (스크롤 가능하도록 전체 목록 반환)
    private var displayedSnippets: [SnippetEntry] {
        return viewModel.snippets
    }

    var body: some View {
        configureMainContent(mainContent)
    }

    private func configureMainContent(_ content: some View) -> some View {
        applyLifecycleLogic(applyStyle(content))
    }

    private func applyStyle(_ content: some View) -> some View {
        content
            .background(Color.clear)
            // Issue 347: 크래시 수정 - 모든 루트 프레임 제약 조건 제거.
            // SnippetNonActivatingWindow가 setFrame/setContentSize를 통해 크기를 제어하도록 함.
            .popupKeyboardHandler(keyboardHandler)
    }

    private func applyLifecycleLogic(_ content: some View) -> some View {
        content
            .onAppear {
                setupInitialState()
            }
            .onChange(of: viewModel.selectedIndex) { oldValue, newValue in
                logV("🗯️ viewModel.selectedIndex 변경: \(oldValue) → \(newValue)")
                keyboardHandler.setSelectedIndex(newValue)
                updateTrigger.toggle()  // UI 강제 업데이트
            }
            .onChange(of: keyboardHandler.selectedIndex) { oldValue, newValue in
                viewModel.updateSelectedIndex(newValue)
                updateTrigger.toggle()
                // Issue 219-1: 키보드 선택 시 미리보기 업데이트
                // Issue261 수정: 리스트가 비어있지 않을 때만 미리보기 업데이트
                if !displayedSnippets.isEmpty {
                    updatePreview(for: newValue)
                } else {
                    logV("🗯️ [UI] 빈 리스트 상태에서 selectedIndex 변경 무시")
                }
            }
            // ✅ Issue170: 뷰모델의 초기 검색어 변경 시 검색창에도 반영 (Window 재사용 시 onAppear 호출 안 될 경우 대비)
            .onChange(of: viewModel.initialSearchTerm) { _, newValue in
                self.searchText = newValue
                logV("🗯️ [UI] 초기 검색어 동기화: '\(newValue)'")
            }
            // ✅ Issue219_1: 리스트 업데이트 시(초기 진입 포함) 첫 번째 항목 미리보기 강제 표시
            .onChange(of: viewModel.listUpdateTrigger) { _, _ in
                // 약간의 딜레이를 주어 윈도우가 자리를 잡은 후 표시 (특히 초기 진입 시)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if !displayedSnippets.isEmpty {
                        // 첫 번째 항목 선택 및 미리보기 업데이트
                        logV(
                            "🗯️ [UI] 리스트 업데이트 감지 -> 첫 번째 항목 미리보기 표시 (count: \(displayedSnippets.count))"
                        )
                        updatePreview(for: 0)
                    } else {
                        // ✅ Issue261 Fix: 검색 결과 없음 -> 프리뷰 숨김 (명시적 로그)
                        logI("🗯️ [Issue261] 리스트 비어있음 (count: 0) -> 프리뷰 숨김 호출")
                        SnippetPreviewManager.shared.hide()
                    }
                }
            }
            // ✅ Issue 184: 설정의 popupRows 변경 시 UI 갱신 유도
            .onChange(of: settings.popupRows) { _, newValue in
                logI("🗯️ [UI] 설정에서 팝업 행 수 변경됨: \(newValue)")
                updateTrigger.toggle()
            }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            searchBar
            snippetList
        }
    }

    // MARK: - Components

    private var searchBar: some View {
        ZStack {
            // Background to ensure drag area color matches
            Color.clear  // Allow VisualEffectView to show through

            // 검색 입력 필드 컨테이너
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .bold))  // Slightly smaller/bolder icon

                searchTextField

                if !searchText.isEmpty {
                    clearButton
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.08))  // 입력 필드를 위한 더 어두운 배경
            .cornerRadius(6)
            .padding(.horizontal, 8)  // 수평 드래그 여백
            .padding(.vertical, 4)  // 수직 드래그 여백 (헤더 높이 내에 맞춤)
        }
        .frame(height: PopupUIConstants.headerHeight)  // 하드코딩된 36 대신 상수 사용
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .bottom
        )
    }

    private var searchTextField: some View {
        TextField(NSLocalizedString("popup.search.placeholder", comment: ""), text: $searchText)
            .textFieldStyle(PlainTextFieldStyle())
            .font(.system(size: 13))  // 컨테이너에 맞게 폰트 크기 약간 조정
            .focused($isSearchFocused)
            .popupKeyboardHandler(keyboardHandler)
            .onSubmit {
                keyboardHandler.confirmSelection()
            }
            .onChange(of: searchText) { _, newValue in
                handleSearchTextChange(newValue)
            }
            // ✅ Issue 352: Cmd+A로 전체 텍스트 선택 지원
            // NSHostingView 내부의 TextField는 키 윈도우가 아니거나 메뉴가 없으면 메뉴바 명령을 놓치는 경우가 많음.
            // NSTextField 로직을 해킹하거나 SwiftUI가 지원하는지 확인하여 수동으로 구현함.
            // SwiftUI TextField에는 직접적인 'selectAll'이 없음.
            // 그러나 일반적인 macOS Cmd+A는 애플리케이션이 지원하면 작동함.
            // fSnippet이 메뉴바 없는 LSUIElement 앱인 경우 Cmd+A가 실패할 수 있음.
            // 선택 처리를 강제하는 키보드 단축키를 추가함.
            .background(
                Button("Select All") {
                    // Hack to send "Select All" to the focused field
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a", modifiers: .command)
                .opacity(0)
            )
    }

    private var clearButton: some View {
        Button(action: { searchText = "" }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.trailing, 0)  // 컨테이너가 처리하므로 이전 패딩 제거
    }

    private func handleSearchTextChange(_ newValue: String) {
        // ✅ Issue177 Fix: 1단계 - 현재 표시된 후보 스니펫과 정확 일치 확인 (최우선)
        // ⚠️ Issue330: 사용자 되돌리기 - "부분 일치 허용".
        // 즉시 실행은 더 긴 약어(예: 'bfl' 대 'bf') 입력을 방지함.
        // 따라서 여기서 자동 정확 일치 트리거링을 비활성화함.
        // 사용자는 실행하려면 Enter 또는 트리거 키(접미사)를 눌러야 함.

        /* [DISABLED for Issue 330]
        if let exactMatch = viewModel.snippets.first(where: { $0.abbreviation == newValue }) {
            logV("🗯️ [Issue177] 정확 일치 스니펫 발견: '\(newValue)' -> 즉시 실행")
        
            // suffix 길이 동적 계산
            let ruleManager = RuleManager.shared
            var suffixLength = 1 // 기본값 (트리거키 1글자)
        
            // 폴더 규칙 확인
            if let rule = ruleManager.getRule(for: exactMatch.folderName) {
                if !rule.suffix.isEmpty {
                    suffixLength = rule.suffix.count
                    logV("🗯️ [Issue177] 폴더 규칙 suffix 길이: \(suffixLength) ('\(rule.suffix)')")
                }
            } else {
                // 기본 트리거키 사용
                let defaultSymbol = settings.settings.defaultSymbol
                if !defaultSymbol.isEmpty {
                    suffixLength = defaultSymbol.count
                    logV("🗯️ [Issue177] 기본 트리거키 길이: \(suffixLength) ('\(defaultSymbol)')")
                }
            }
        
            // searchText를 suffix 제거한 상태로 설정
            let cleanTerm = String(newValue.dropLast(suffixLength))
        
            // ✅ Issue184: 더 긴 suffix 스니펫 존재 시 자동 실행 보류
            var usedSuffix = ""
            if let rule = ruleManager.getRule(for: exactMatch.folderName), !rule.suffix.isEmpty {
                usedSuffix = rule.suffix
            } else {
                usedSuffix = settings.settings.defaultSymbol
            }
        
            if !usedSuffix.isEmpty {
                let allRules = ruleManager.getAllRules().filter { !$0.suffix.isEmpty }.sorted { $0.suffix.count > $1.suffix.count }
                let matcher = AbbreviationMatcher()
                if let longerRule = allRules.first(where: { r in
                    r.suffix.count > usedSuffix.count && r.suffix.hasPrefix(usedSuffix) && matcher.findSnippetByAbbreviation(cleanTerm + r.suffix) != nil
                }) {
                    logV("🗯️ ⏸️ [Issue184] Exact-match blocked by longer suffix: input='\(newValue)', block='\(longerRule.suffix)', target='\(cleanTerm + longerRule.suffix)'")
                    // 자동 실행을 보류하고 아래 일반 suffix 처리 흐름으로 위임
                    return
                }
            }
        
            self.searchText = cleanTerm
            viewModel.onSearchTermChanged?(cleanTerm)
            viewModel.onSelection?(exactMatch)
            return
        }
        */

        // ✅ Issue177 Fix: 2단계 - Suffix 감지 및 트리거 실행 (정확 일치 없을 경우에만)
        let ruleManager = RuleManager.shared
        let allRules = ruleManager.getAllRules()

        // Suffix 길이 역순으로 정렬 (긴 suffix 우선 매칭: ,, before ,)
        let sortedRules = allRules.filter { !$0.suffix.isEmpty }.sorted {
            $0.suffix.count > $1.suffix.count
        }

        // 기본 트리거키도 포함 (유효한 경우)
        let defaultSymbol = settings.settings.defaultSymbol

        // 2-1. Rule 기반 Suffix 체크
        for rule in sortedRules {
            if newValue.hasSuffix(rule.suffix) {
                logV("🗯️ [Issue177] Suffix 감지: '\(rule.suffix)' (Rule: \(rule.name))")
                executeTrigger(newValue: newValue, suffix: rule.suffix, rules: sortedRules)
                return
            }
        }

        // 2-2. Default Symbol 체크 (Rule에 없을 경우 대비)
        if !defaultSymbol.isEmpty && newValue.hasSuffix(defaultSymbol) {
            logV("🗯️ [Issue177] Default Symbol 감지: '\(defaultSymbol)'")
            executeTrigger(newValue: newValue, suffix: defaultSymbol, rules: sortedRules)
            return
        }

        // ✅ Issue170: 뷰모델에 검색어 변경 알림 -> 컨트롤러가 필터링 수행
        logV("🗯️ 검색어 변경: \(newValue)")
        viewModel.onSearchTermChanged?(newValue)
    }

    // MARK: - Snippet 목록

    private var snippetList: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // ✅ Issue 356 & 357: 제안된 생성 용어가 있으면 상단에 표시
                if let suggestedTerm = viewModel.suggestedCreateTerm {
                    Button(action: {
                        // ✅ Issue9: 스니펫 생성 → 유료 버전 전용 안내
                        logI("🗯️ [Issue9] Create New Snippet blocked - Paid version only: \(suggestedTerm)")
                        PaidAppManager.shared.handlePaidFeature()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 16))
                            Text(
                                String(
                                    format: NSLocalizedString("popup.create.button", comment: ""),
                                    suggestedTerm)
                            )
                            .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                    Text("popup.create.help")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }

                if displayedSnippets.isEmpty && !searchText.isEmpty {
                    // ✅ Issue 257: 빈 상태 (레거시 폴백)
                    // Controller에서 Top10으로 Fallback하므로 이 경로는 거의 타지 않음
                    VStack {
                        Spacer()
                        Text("popup.empty.no_results")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(displayedSnippets.enumerated()), id: \.offset) {
                                index, snippet in
                                let isCurrentlySelected = index == keyboardHandler.selectedIndex

                                SnippetRowView(
                                    snippet: snippet,
                                    isSelected: isCurrentlySelected,
                                    shortcut: getShortcut(for: index),
                                    onTap: {
                                        handleRowTap(index: index)
                                    },
                                    onEdit: {
                                        handleEdit(snippet: snippet)
                                    },
                                    onHover: { isHovering in
                                        if isHovering && viewModel.selectedIndex != index {
                                            viewModel.updateSelectedIndex(index)
                                            keyboardHandler.selectedIndex = index
                                        }
                                    }
                                )
                                .id(index)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .background(Color.clear)  // VisualEffectView가 보이도록 네이티브 배경 지움

                    // Issue 347: 크래시 수정 - ScrollView 높이 제약 조건 제거.
                    .onChange(of: keyboardHandler.selectedIndex) { _, newValue in
                        scrollToSelectedItem(proxy: proxy, index: newValue)
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    private func setupInitialState() {
        logI("🗯️ setupInitialState 호출 - viewModel.selectedIndex: \(viewModel.selectedIndex)")

        // Issue 219-1: 초기 미리보기
        // SnippetPopover가 윈도우를 등록했는지 확인하기 위해 asyncAfter 사용 ("초기 미리보기가 보이지 않는 문제" 수정)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            updatePreview(for: 0)
        }

        // 첫 번째 항목이 선택되었는지 확인
        if !displayedSnippets.isEmpty {
            viewModel.updateSelectedIndex(0)
            keyboardHandler.selectedIndex = 0
        }

        logV(
            "🗯️ 초기 상태 설정 완료 - selectedIndex: \(viewModel.selectedIndex), keyboardHandler.selectedIndex: \(keyboardHandler.selectedIndex)"
        )

        /* ✅ Issue604: 버퍼 문자열 숨김 (사용자 요청)
        // ✅ Issue169: 버퍼에서 전달된 검색어 설정
        if !viewModel.initialSearchTerm.isEmpty {
            self.searchText = viewModel.initialSearchTerm
            logV("🗯️ 초기 검색어 설정됨: '\(viewModel.initialSearchTerm)'")
        }
        */

        // ✅ 검색창에 포커스 설정 (딜레이 후 실행해야 안전)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isSearchFocused = true
            logV("🗯️ 검색창 포커스 요청됨")
        }

        // 시스템 포커스 요청 (약간의 지연 후)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            requestSystemFocus()
        }
    }

    private func handleRowTap(index: Int) {
        keyboardHandler.setSelectedIndex(index)
        keyboardHandler.confirmSelection()
    }

    private func scrollToSelectedItem(proxy: ScrollViewProxy, index: Int) {
        if index >= 0 && index < displayedSnippets.count {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(index, anchor: .center)
            }
        }
    }

    private func requestSystemFocus() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.keyWindow {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    /// ✅ Issue183: 통합된 엄격한 트리거 로직 (Issue177 & Issue182 통합 수정)
    /// 요구사항:
    /// 1. 길이 동등성: Input.length == Target.length
    /// 2. 내용 동등성: Input == Target
    /// 3. 자동 Enter 동작: 입력이 트리거일 *때만* 실행.
    private func executeTrigger(
        newValue: String, suffix: String, rules: [RuleManager.CollectionRule]
    ) {
        let cleanTerm = String(newValue.dropLast(suffix.count))
        let matcher = AbbreviationMatcher()

        // Issue184: 더 긴 suffix 가드
        // 만약 현재 입력이 더 긴 suffix 스니펫의 접두 상태라면(예: ",,"의 일부인 "," 상태)
        // 해당 더 긴 suffix를 필요로 하는 동일 키워드 스니펫이 존재하는지 확인하고, 존재하면 실행을 보류한다.

        // 1. 후보 식별 (이중 조회)
        // 전체 입력 또는 접미사가 제거된 입력과 일치하는 스니펫 찾기 시도.
        var candidate: SnippetEntry? = nil

        if let exactMatchFull = matcher.findSnippetByAbbreviation(newValue) {
            candidate = exactMatchFull
            logV("🗯️ [Issue183] Candidate Found (Full): '\(newValue)' -> \(candidate!.abbreviation)")
        } else if let exactMatchStripped = matcher.findSnippetByAbbreviation(cleanTerm) {
            candidate = exactMatchStripped
            logV(
                "🗯️ [Issue183] Candidate Found (Stripped): '\(cleanTerm)' -> \(candidate!.abbreviation)"
            )
        }

        if candidate == nil {
            logV("🗯️️ [Issue183] No candidate found for '\(newValue)' or '\(cleanTerm)'")
            return
        }
        let snippet = candidate!

        // 2. 타겟 구성
        // 이 스니펫을 트리거하기 위해 사용자가 *반드시* 입력해야 하는 것 결정.
        // 규칙: Target = Key + (Key에 없는 경우 Suffix)

        let folderName = snippet.folderName
        let ruleManager = RuleManager.shared
        var targetTriggerString = snippet.abbreviation
        var requiredSuffix = ""

        if let rule = ruleManager.getRule(for: folderName) {
            requiredSuffix = rule.suffix
        } else {
            // 일반 폴더 로직 (특정 규칙 없음)
            // ✅ Issue184 수정: 감지에서 전달된 'suffix'를 신뢰하지 않음 (다른 규칙에서 왔을 수 있음).
            // 대신, 이 스니펫 폴더의 기본 심볼(또는 폴더 심볼)을 강제함.
            let settings = SettingsManager.shared.load()
            requiredSuffix =
                settings.folderSymbols[folderName.lowercased()] ?? settings.defaultSymbol

            // 스니펫 키 자체가 이미 Suffix를 포함하고 있는지 확인 (예: "div," 로 저장됨)
            // 아래 타겟 구성에서 hasSuffix를 사용하여 이를 확인함.
        }

        // 저장된 키가 필수 Suffix로 끝나지 않으면 타겟에 추가함.
        // 예: Key="git" (Space suffix), Suffix=" " -> Target="git "
        // 예: Key="div,," (,, suffix), Suffix=",," -> Target="div,," (변경 없음)
        if !requiredSuffix.isEmpty && !snippet.abbreviation.hasSuffix(requiredSuffix) {
            targetTriggerString += requiredSuffix
        }

        // 3. 엄격한 검증 ("자동 Enter" 체크)
        // 조건: Input이 Target과 정확히 일치, 또는 Input이 Clean + Default Trigger와 일치.

        // ✅ Issue 339 확인: requiredSuffix가 비어있으면 정확하더라도 자동 실행하지 않음.
        // 이는 "필터링을 위한 타이핑"이 "실행을 위한 타이핑"이 되는 것을 방지함.
        if requiredSuffix.isEmpty && newValue == snippet.abbreviation {
            logV(
                "🗯️ [Issue339] Suffix Empty Block: Prevents execution of '\(newValue)' without trigger."
            )
            return
        }

        // ✅ Issue 330 개선: 팝업 모드에서 기본 트리거 키를 범용 트리거로 허용.
        let settings = SettingsManager.shared.load()
        let defaultSymbol = settings.defaultSymbol

        let matchesTarget = (newValue == targetTriggerString)
        let matchesDefaultTrigger =
            (!defaultSymbol.isEmpty && newValue == snippet.abbreviation + defaultSymbol)

        // ✅ Issue 339 범용 트리거를 위한 Suffix 가드
        // 범용 트리거가 일치하면(matchesDefaultTrigger), 더 긴 suffix의 일부일 가능성을 확인함.
        if matchesDefaultTrigger {
            // 기본 심볼로 시작하는 더 긴 규칙 suffix(예: ",,")가 있는지 확인
            // 그리고 사용자가 그것을 타이핑하고 있을 수 있는지 확인.
            let matcher = AbbreviationMatcher()
            let cleanTerm = snippet.abbreviation
            let potentialLongerMatch = rules.contains { r in
                r.suffix.count > defaultSymbol.count && r.suffix.hasPrefix(defaultSymbol)
                    && matcher.findSnippetByAbbreviation(cleanTerm + r.suffix) != nil
            }

            if potentialLongerMatch {
                logV(
                    "🗯️ ⏸️ [Issue339] Universal Trigger Blocked by Multi-char Suffix Guard (e.g. ',,'): Waiting..."
                )
                return
            }
        }

        if !matchesTarget && !matchesDefaultTrigger {
            logV("🗯️ [Issue183] Strict Mismatch:")
            logV("🗯️     - Input : '\(newValue)'")
            logV("🗯️     - Target: '\(targetTriggerString)'")
            logV("🗯️     - AltTrg: '\(snippet.abbreviation + defaultSymbol)'")
            return
        }

        // 4. 실행
        logV("🗯️ [Issue183] EXECUTE: '\(newValue)' matches Target or Default Trigger")

        self.searchText = cleanTerm
        viewModel.onSearchTermChanged?(newValue)
        viewModel.onSelection?(snippet)
        return
    }
    // MARK: - Action Handlers

    // Issue 219: Edit Feature
    // Issue 219: 편집 기능
    private func handleEdit(snippet: SnippetEntry) {
        // ✅ Issue9: 스니펫 편집 → 유료 버전 전용 안내
        logI("🗯️️ [Issue9] Edit blocked - Paid version only: \(snippet.abbreviation)")
        PaidAppManager.shared.handlePaidFeature()
    }

    // Issue 219-1: 선택 기반 미리보기 (Hover 대체)
    private func updatePreview(for index: Int) {
        // Ensure index is valid
        guard index >= 0 && index < displayedSnippets.count else {
            // ✅ Fix: Layout Cycle Crash - Must be async
            DispatchQueue.main.async {
                SnippetPreviewManager.shared.hide()
            }
            return
        }

        let snippet = displayedSnippets[index]
        SnippetPreviewManager.shared.show(snippet: snippet, relativeTo: NSRect.zero)
    }

    // Issue 219: 호버 미리보기 - 선택 기반을 위해 비활성화됨
    private func handleHover(snippet: SnippetEntry, isHovering: Bool) {
        // Issue 219-1: 호버 트리거 비활성화됨.
        // 여기서 아무것도 하지 않음. 미리보기는 선택에 의해 제어됨.
    }

    // ✅ Issue 230: 빠른 선택 단축키 헬퍼
    private func getShortcut(for index: Int) -> String? {
        // ✅ Issue604: 사용자 요청으로 단축키 힌트 표시 안 함.
        return nil
    }
}

// MARK: - Preview

struct SnippetPopupView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = SnippetPopupViewModel()

        let _ = {
            viewModel.snippets = [
                SnippetEntry(
                    id: "1",
                    abbreviation: "bhead=",
                    filePath: URL(fileURLWithPath: "/test/head.sh"),
                    folderName: "Bash",
                    fileName: "head.sh",
                    description: "Display first lines of file",
                    snippetDescription: "Head Command",
                    content: "head -n 10 file.txt",
                    tags: ["bash", "sh"],
                    fileSize: 1024,
                    modificationDate: Date(),
                    isActive: true
                ),
                SnippetEntry(
                    id: "2",
                    abbreviation: "jclass=",
                    filePath: URL(fileURLWithPath: "/test/class.java"),
                    folderName: "Java",
                    fileName: "class.java",
                    description: "Basic Java class template",
                    snippetDescription: "Java Class",
                    content: "public class MyClass { }",
                    tags: ["java"],
                    fileSize: 2048,
                    modificationDate: Date(),
                    isActive: true
                ),
            ]
        }()

        SnippetPopupView(viewModel: viewModel)
            .frame(width: 350, height: 200)
            .padding()
    }
}
