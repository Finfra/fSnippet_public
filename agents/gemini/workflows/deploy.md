---
name: deploy
description: "[RELEASE ONLY] 디버그 빌드를 /Applications에 배포하고, 버전을 올리며, 앱을 교체합니다."
---

> [!CAUTION]
> **릴리스 전용 (Use Only for Releases)**: 이 워크플로우는 **앱 버전을 증가(Bump Version)**시키고 현재 설치된 앱을 **보관(Archive) 및 교체(Replace)**합니다.
> **단순 검증용 (For Verification Only)**: `/verify`를 사용하세요.

1. **릴리스 배포 실행 (Execute Release Deployment)**:
   - 버전 증가 (예: 0.85 -> 0.86)
   - 현재 앱 보관 (Archive)
   - `/Applications/_nowage_app/fSnippet.app` 빌드 및 교체

   ```bash
   .agent/skills/deployment/scripts/deploy.sh
   ```
