class FsnippetCli < Formula
  desc "Text snippet expansion engine daemon for fSnippet"
  homepage "https://github.com/Finfra/fSnippet_public"
  url "https://github.com/Finfra/fSnippet_public/releases/download/cli-v1.1.1/fSnippetCli-1.1.1.tar.gz"
  version "1.1.1"
  sha256 "b8f0388e4adff2790aa5f30801b47a837b3b52161d49ef9d46161f3286d8c1c2"
  license "Apache-2.0"

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

      License: the source code is Apache-2.0 — build it yourself and use it without limit.
      This Official Build is free for personal use, education, non-profits, open-source
      projects and organizations up to 250 concurrent copies; beyond that, or for resale,
      bundling or hosting, see DISTRIBUTION-TERMS.md and COMMERCIAL.md in the repository.

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
