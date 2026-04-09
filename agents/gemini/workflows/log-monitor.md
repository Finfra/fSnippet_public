---
name: log-monitor
description: "실시간 로그 분석 및 모니터링 시작 (Startup, Snippet, Spam check)"
---

**역할**: `flog.log`를 분석하여 앱의 상태를 진단하고 실시간 모니터링을 시작합니다. `/run` 워크플로우와 함께 사용됩니다.

1.  **로그 분석 및 모니터링 실행**:
    - `.agent/skills/log_monitor/scripts/monitor.sh`를 실행하여 현재 로그 상태(Startup, Snippet)를 분석합니다.
    - 실행 후 팁에 따라 `tail -f` 명령어로 실시간 로그를 확인하세요.
    ```bash
    sh .agent/skills/log_monitor/scripts/monitor.sh
    ```

2.  **분석 항목**:
    - **Startup Sequence**: 앱 실행 초기화 과정이 정상적으로 완료되었는지 확인합니다.
    - **Snippet Verification**: 최근 스니펫 트리거 및 확장 성공 여부를 확인합니다.
    - **Spam Analysis**: 최근 로그 중 과도하게 반복되는 라인을 탐지합니다.

3.  **실시간 모니터링 (Optional)**:
    - 터미널에서 직접 실행하여 키 입력과 로그를 동시에 확인하려면:
    ```bash
    # 별도의 탭에서 실행
    tail -f ~/Documents/finfra/fSnippet/logs/flog.log
    ```
