class Fsnippetcli < Formula
  desc "Text snippet expansion engine daemon for fSnippet"
  homepage "https://github.com/Finfra/fSnippet_public"
  url "https://github.com/Finfra/fSnippet_public/archive/refs/tags/cli-v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["15.0", :build]

  def install
    system "xcodebuild", "-project", "fSnippetCli.xcodeproj",
           "-scheme", "fSnippetCli",
           "-configuration", "Release",
           "-derivedDataPath", buildpath/"build",
           "MACOSX_DEPLOYMENT_TARGET=14.0",
           "SYMROOT=#{buildpath}/build",
           "CODE_SIGN_IDENTITY=-",
           "CODE_SIGNING_REQUIRED=NO",
           "CODE_SIGNING_ALLOWED=NO"
    prefix.install Dir["build/Release/fSnippetCli.app"]
  end

  def caveats
    <<~EOS
      fSnippetCli는 접근성(Accessibility) 권한이 필요합니다.

      설치 후 다음 단계를 수행하세요:
        1. 시스템 설정 > 개인정보 보호 및 보안 > 접근성
        2. fSnippetCli.app 항목에 체크

      자동 시작 설정:
        앱 설정에서 "로그인 시 자동 시작" 옵션을 활성화하세요.
    EOS
  end

  test do
    assert_predicate prefix/"fSnippetCli.app/Contents/MacOS/fSnippetCli", :exist?
  end
end
