class FsnippetCli < Formula
  desc "Text snippet expansion engine daemon for fSnippet"
  homepage "https://github.com/Finfra/fSnippet_public"
  url "https://github.com/Finfra/fSnippet_public/releases/download/cli-v1.1.1/fSnippetCli-1.1.1.tar.gz"
  version "1.1.1"
  sha256 "bca7eab18799e34924cee570aa9dc9ad4940a63a9653ac1e44d6c076b2aadd05"
  license "MIT"

  depends_on :macos

  def install
    # Pre-built fSnippetCli.app is included in tarball (Apple Development signature retained).
    # Keychain access is restricted in brew sandbox, so we copy as-is without rebuilding.
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
      fSnippetCli requires Accessibility permissions.

      To enable auto-start after installation:
        brew services start finfra/tap/fsnippet-cli

      To grant Accessibility permissions:
        System Settings > Privacy & Security > Accessibility > fSnippetCli

      If TCC permissions are corrupted, reset via Xcode Debug path: /run tcc
    EOS
  end

  test do
    assert_predicate prefix/"fSnippetCli.app/Contents/MacOS/fSnippetCli", :exist?
  end
end
