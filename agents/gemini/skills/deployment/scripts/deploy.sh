#!/bin/bash
set -e

# deploy.sh
# fSnippet 자동 배포 스크립트
# 사용법: ./deploy.sh

# 프로젝트 루트 경로 설정 (스크립트 위치: .agent/skills/deployment/scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../../../.."
PROJECT_DIR="$PROJECT_ROOT/fSnippet"

cd "$PROJECT_ROOT"

echo "📂 Project Root: $PROJECT_ROOT"

# --- 1. 버전 증가 (Version Bump) ---
echo "⬆️  버전 증가 중..."

if [ -d "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR/fSnippet.xcodeproj" ]; then
    cd "$PROJECT_DIR"
else
    echo "❌ 오류: 프로젝트 디렉토리를 찾을 수 없습니다: $PROJECT_DIR"
    exit 1
fi

# 현재 빌드 번호 확인
current_ver=$(agvtool what-version -terse)
echo "   현재 빌드: $current_ver"

# 다음 버전 계산
next_ver=$(echo "$current_ver + 0.01" | bc)
if [ -z "$next_ver" ]; then
    next_ver=$(echo $current_ver | awk '{print $1 + 0.01}')
fi

echo "   다음 버전: $next_ver"

# Marketing Version 업데이트
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = $next_ver;/g" fSnippet.xcodeproj/project.pbxproj

# Project Version (Build Number) 업데이트
agvtool new-version -all $next_ver
# agvtool 실패 대비 안전장치
sed -i '' "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = $next_ver;/g" fSnippet.xcodeproj/project.pbxproj

echo "✅ 버전이 $next_ver 로 증가되었습니다."

# --- 2. 기존 프로세스 종료 ---
echo "🚫 기존 fSnippet 프로세스 종료 중..."
pkill -f MacOS/fSnippet || true

# --- 2.1 기존 앱 아카이빙 (Archive Old Version) ---
# --- 2.1 기존 앱 아카이빙 (Archive Old Version) ---
# --- 2.1 기존 앱 아카이빙 (Archive Old Version) ---
APP_PATH="/Applications/_nowage_app/fSnippet.app"
if [ -d "$APP_PATH" ]; then
    echo "📦 기존 앱 확인 중..."
    
    # Clean up bad artifact
    if [ -f "/Applications/_nowage_app/fSnippet_v.zip" ]; then
        echo "   🗑 잘못된 아카이브 삭제: fSnippet_v.zip"
        rm "/Applications/_nowage_app/fSnippet_v.zip"
    fi

    if [ -f "$APP_PATH/Contents/Info.plist" ]; then
        RAW_VER=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString)
        
        # Normalize Version: .72 -> 0.72
        # Use simple string replacement/check
        if [[ "$RAW_VER" == .* ]]; then
             # Remove leading dot then prepend 0.
             CLEAN_VER="${RAW_VER#.}"
             OLD_VER="0.${CLEAN_VER}"
        else
             OLD_VER="$RAW_VER"
        fi
        
        echo "   기존 버전: v$OLD_VER (Raw: $RAW_VER)"
        
        ARCHIVE_NAME="fSnippet_v${OLD_VER}.zip"
        ARCHIVE_PATH="/Applications/_nowage_app/$ARCHIVE_NAME"
        
        # 이미 아카이브가 있는지 확인 후 없으면 아카이빙
        if [ ! -f "$ARCHIVE_PATH" ]; then
            echo "   🗜 v${OLD_VER} 아카이빙 실행..."
            
            # Capture output
            (cd /Applications/_nowage_app && zip -r "$ARCHIVE_NAME" fSnippet.app) || echo "   ❌ Zip command failed"
            
            if [ -f "$ARCHIVE_PATH" ]; then
                 echo "   ✅ 아카이빙 성공: $ARCHIVE_NAME"
            else
                 echo "   ❌ 아카이빙 실패: 파일이 생성되지 않았습니다. ($ARCHIVE_PATH)"
                 echo "   ⚠️ 권한 문제일 수 있습니다. 터미널에 Full Disk Access가 있는지 확인하세요."
                 exit 1 
            fi
        else
            echo "   ℹ️ v${OLD_VER} 아카이브가 이미 존재합니다."
        fi
    else
        echo "⚠️ 경고: Info.plist를 찾을 수 없어 버전을 확인할 수 없습니다."
    fi
    
    echo "🗑 기존 앱 삭제..."
    rm -rf "$APP_PATH"
fi

# --- 3. Debug 버전 빌드 ---
echo "🔨 Debug 스킴 빌드 중..."
xcodebuild -scheme fSnippet -configuration Debug build -quiet

# --- 4. 배포 (Deploy) ---
echo "📦 /Applications 로 배포 중..."

BUILD_DIR=$(xcodebuild -scheme fSnippet -showBuildSettings | grep " TARGET_BUILD_DIR =" | awk -F " = " '{print $2}' | xargs)

if [ -d "$BUILD_DIR/fSnippet.app" ]; then
    mkdir -p /Applications/_nowage_app
    rm -rf /Applications/_nowage_app/fSnippet.app
    cp -R "$BUILD_DIR/fSnippet.app" /Applications/_nowage_app/
    
    # Quarantine 속성 제거
    xattr -cr /Applications/_nowage_app/fSnippet.app
    
    # 아카이빙 (Archive)
    VERSION=$(agvtool what-marketing-version -terse1)
    (cd /Applications/_nowage_app && zip -r "fSnippet_v${VERSION}.zip" fSnippet.app)
    
    echo "✅ 배포 완료: /Applications/_nowage_app/fSnippet.app"
else
    echo "❌ 빌드 실패 또는 파일을 찾을 수 없음"
    exit 1
fi

# --- 5. 앱 실행 ---
echo "🚀 앱 실행 중..."
open /Applications/_nowage_app/fSnippet.app

# --- 6. Save Point 및 커밋 ---
echo "📝 Issue.md 업데이트 및 커밋 중..."

cd "$PROJECT_ROOT"
DATE=$(date +%Y.%m.%d)

# 1. Main Release Commit (Code + Version Bump)
git commit -am "Build $next_ver: Release & Deploy"
RELEASE_HASH=$(git rev-parse --short HEAD)
echo "   Release Commit Hash: $RELEASE_HASH"

# 2. Update Issue.md with Save Point (Linking to Release Hash)
if [ -f "Issue.md" ]; then
    sed -i '' "/\* Save Point :/a\\
      - $DATE v$next_ver Release ($RELEASE_HASH)
    " Issue.md
    echo "   Issue.md에 Save Point 추가됨 ($RELEASE_HASH)"
else
    echo "⚠️ 경고: 루트에서 Issue.md를 찾을 수 없습니다."
fi

# 3. Issue Archiving (완료된 이슈 이동)
echo "📦 완료된 이슈 아카이빙 중..."
if [ -f ".agent/skills/deployment/scripts/archive-issues.py" ]; then
    python3 .agent/skills/deployment/scripts/archive-issues.py \
        --version "$next_ver" \
        --date "$DATE" \
        --issue-file "Issue.md" \
        --old-issue-file "_doc_work/Issue_OLD.md"
else
    echo "⚠️ 경고: 아카이빙 스크립트를 찾을 수 없습니다."
fi

# 4. Documentation Commit (Update Issue.md)
git add Issue.md _doc_work/Issue_OLD.md
git commit -m "Docs: Update Issue.md for v$next_ver (Hash: $RELEASE_HASH)"
git push

echo "🎉 배포 완료! v$next_ver"
