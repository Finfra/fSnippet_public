---
name: SKILL
description: 빌드 에러 발생 시 로그를 분석하고 해결책을 제시합니다. (xcodebuild, DerivedData, Signing 등)
---

# Build Doctor Skill (빌드 에러 해결)

이 스킬은 `xcodebuild` 실패 시 원인을 파악하고 복구하는 방법을 안내합니다.

## 1. 진단 (Diagnosis)
빌드가 실패하면 터미널 출력에서 **"BUILD FAILED"** 위쪽의 에러 메시지를 확인해야 합니다.

### 로그 확인 방법
```bash
# 최근 빌드 로그 확인 (flog.log 또는 터미널 출력)
tail -n 50 ~/Documents/finfra/fSnippet/logs/flog.log
```

## 2. 공통 해결책 (Common Fixes)

### A. Clean Build & DerivedData 삭제 (가장 강력한 해결책)
빌드 캐시가 꼬였을 때 사용합니다.
```bash
# 1. DerivedData 삭제
rm -rf ~/Library/Developer/Xcode/DerivedData/fSnippet-*

# 2. Clean Build (프로젝트 폴더로 이동 필수)
cd fSnippet
xcodebuild -scheme fSnippet -configuration Debug clean
```

### B. 패키지 캐시 초기화 (Package Resolution Failed)
Swift Package Manager(SPM) 의존성 문제 발생 시 사용합니다.
```bash
# 패키지 리셋 및 업데이트
xcodebuild -resolvePackageDependencies
```

### C. 프로세스 정리 (Simultaneous Access)
이전 빌드나 앱 프로세스가 파일을 점유하고 있을 때 사용합니다.
```bash
# fSnippet 관련 프로세스 강제 종료
pkill -f MacOS/fSnippet || true
```

## 3. 유형별 에러 가이드

| 에러 키워드                            | 원인                                 | 해결책                                                                                                     |
| :------------------------------------- | :----------------------------------- | :--------------------------------------------------------------------------------------------------------- |
| `Code Signing`, `Provisioning Profile` | 서명/인증서 만료 또는 불일치         | Xcode를 열어 **Signing & Capabilities** 탭에서 'Automatically manage signing' 재체크 또는 계정 로그인 확인 |
| `Segmentation fault: 11`               | Swift 컴파일러 버그 또는 복잡한 수식 | 최근 변경한 코드의 복잡도를 낮추거나, Clean Build 실행                                                     |
| `No such module`                       | 모듈 경로 또는 패키지 누락           | SPM 의존성 확인, `xcodebuild -resolvePackageDependencies` 실행                                             |
| `Cycle inside ...`                     | 타겟 간 순환 참조                    | 빌드 페이즈(Build Phases) 순서 확인 및 재정렬                                                              |

## 4. Xcode로 디버깅 (Deep Dive)
터미널에서 해결이 안 되면 Xcode를 열어서 확인하는 것이 빠릅니다.
```bash
xopen . # 현재 폴더의 프로젝트 열기
```
