class FsnippetCli < Formula
  desc "Text snippet expansion engine daemon for fSnippet"
  homepage "https://github.com/Finfra/fSnippet_public"
  url "https://github.com/Finfra/fSnippet_public/archive/refs/tags/cli-v1.0.0.tar.gz"
  version "1.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  depends_on :macos

  def install
    # tarball에 사전 빌드된 fSnippetCli.app 포함됨 (Apple Development 서명 유지).
    # brew sandbox에서는 키체인 접근이 제한되므로 재빌드하지 않고 그대로 복사.
    prefix.install "fSnippetCli.app"
  end

  service do
    run [opt_prefix/"fSnippetCli.app/Contents/MacOS/fSnippetCli"]
    keep_alive successful_exit: false
    log_path var/"log/fsnippet-cli.log"
    error_log_path var/"log/fsnippet-cli.err.log"
    process_type :interactive
  end

  def caveats
    <<~EOS
      fSnippetCli는 접근성(Accessibility) 권한이 필요합니다.

      설치 후 자동 시작 등록:
        brew services start finfra/tap/fsnippet-cli

      권한 승인:
        시스템 설정 > 개인정보 보호 및 보안 > 접근성 > fSnippetCli 체크

      TCC 권한이 꼬이면 Xcode Debug 경로로 재설정: /run tcc
    EOS
  end

  test do
    assert_predicate prefix/"fSnippetCli.app/Contents/MacOS/fSnippetCli", :exist?
  end
end
