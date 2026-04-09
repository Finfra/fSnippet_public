---
name: SKILL
description: 버전을 올리고, 빌드 후 /Applications에 배포하며, 배포 기록을 남깁니다.
---

# Deployment Skill (배포 스킬)

이 스킬은 fSnippet 애플리케이션의 배포 과정을 자동화합니다.

## 필수 조건 (Prerequisites)
- macOS 환경
- Xcode Command Line Tools 설치됨 (`xcodebuild`, `agvtool`)
- 버전 계산을 위한 `bc` 또는 `awk`
- `/Applications/_nowage_app` 폴더에 대한 쓰기 권한

## 사용법 (Usage)

배포 프로세스를 실행하려면 `scripts` 디렉토리에 있는 `deploy.sh` 스크립트를 실행하세요.

### 명령어
```bash
/bin/bash .agent/skills/deployment/scripts/deploy.sh
```

## 기능 설명 (What it does)
1.  **버전 증가 (Version Bump)**: Marketing Version과 Build Number를 0.01씩 증가시킵니다.
2.  **앱 종료 (Stop App)**: 실행 중인 `fSnippet` 인스턴스가 있다면 종료합니다.
3.  **빌드 (Build)**: `Debug` 스킴으로 빌드합니다.
4.  **배포 (Deploy)**: 빌드된 앱을 `/Applications/_nowage_app/` 경로로 복사합니다.
5.  **아카이브 (Archive)**: 새 버전을 zip 파일로 압축하여 보관합니다.
6.  **실행 (Launch)**: 새로 배포된 앱을 실행합니다.
7.  **기록 및 커밋 (Log & Commit)**:
    - `Issue.md`에 "Save Point"를 추가합니다.
    - 표준화된 메시지로 모든 변경 사항을 커밋합니다.
    - 원격 저장소로 푸시(Push)합니다.

## 문제 해결 (Troubleshooting)
- 버전 증가 실패 시, Xcode 프로젝트 설정에서 `agvtool`이 올바르게 구성되었는지 확인하세요.
- 복사 중 권한 오류 발생 시, `/Applications/_nowage_app` 의 권한을 확인하세요.
