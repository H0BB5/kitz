# Homebrew formula for kitz. Lives in your shared tap repo `h0bb5/homebrew-tap`
# at Formula/kitz.rb. Publish flow:
#   1. push this project to GitHub (e.g. H0BB5/kitz) and tag a release:
#        git tag v0.1.2 && git push --tags
#   2. run ./release.sh v0.1.2  → prints the correct url + sha256 to paste below
#   3. push this file to h0bb5/homebrew-tap at Formula/kitz.rb
#   4. users: `brew install h0bb5/tap/kitz`
class Kitz < Formula
  desc "Capture Claude Code commands/skills/plugins on the fly"
  homepage "https://github.com/H0BB5/kitz"
  url "https://github.com/H0BB5/kitz/archive/refs/tags/v0.1.2.tar.gz"
  sha256 "878889ecdafc9cda2596cf9f1ec8e11f984ba24ac3f4e249840e92846f1e2896"
  license "MIT"
  version "0.1.2"

  depends_on "fzf" => :recommended

  def install
    bin.install "bin/kitz"
    %w[cmdz sklz plgz].each { |n| bin.install_symlink bin/"kitz" => n }
  end

  test do
    assert_match "kitz #{version}", shell_output("#{bin}/kitz --version")
    system bin/"cmdz", "smoke", "-m", "hello", "--dir", testpath, "-y"
    assert_predicate testpath/".claude/commands/smoke.md", :exist?
  end
end
