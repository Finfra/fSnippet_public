import Foundation

// MARK: - Help 커맨드

struct HelpCommand {
    static func run() {
        let help = """
        fSnippetCli — 텍스트 스니펫 확장 및 클립보드 히스토리 관리

        사용법:
          fSnippetCli [command] [subcommand] [options]

        서비스 관리:
          (인자없음)               GUI 모드 실행 (기존 동작)
          status                  서비스 상태 출력
          version                 버전 및 빌드 정보

        스니펫:
          snippet list            스니펫 목록
          snippet search <query>  스니펫 검색
          snippet get <id>        스니펫 상세 조회
          snippet expand <abbr>   abbreviation → 텍스트 확장

        클립보드:
          clipboard list          클립보드 히스토리 목록
          clipboard get <id>      클립보드 항목 상세
          clipboard search <q>    클립보드 검색

        폴더:
          folder list             폴더 목록
          folder get <name>       폴더 상세 (스니펫 포함)

        통계:
          stats top               사용 빈도 Top N
          stats history           사용 이력

        설정 (v2 API):
          settings get [key]      설정 조회 (general, popup, behavior, history, advanced, snapshot, shortcuts)
          settings set <k> <v>    설정 변경 (예: popup.popupRows 10)
          settings reset --confirm 모든 설정을 기본값으로 초기화
          settings snapshot export [file]  스냅샷 내보내기
          settings snapshot import <file>  스냅샷 가져오기

        기타:
          trigger                 트리거 키 정보
          config                  현재 설정 출력 (v1 API)
          import alfred <path>    Alfred 스니펫 임포트

        글로벌 옵션:
          -h, --help              도움말 출력
          -v, --version           버전 정보 출력
          -p, --port <port>       API 포트 지정 (기본 3015)
              --json              JSON 형식으로 출력

        공통 옵션 (list, search 계열):
              --limit <n>         결과 개수 제한 (기본 20)
              --offset <n>        결과 시작 위치 (기본 0)
        """
        print(help)
    }
}
