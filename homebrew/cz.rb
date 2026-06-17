# Homebrew formula for cz. Lives in a tap repo named `homebrew-cz`
# at Formula/cz.rb. Publish flow:
#   1. push this project to GitHub (e.g. H0BB5/cz) and tag a release:
#        git tag v0.2.0 && git push --tags
#   2. run ./release.sh v0.2.0  → prints the correct url + sha256 to paste below
#   3. push this file to H0BB5/homebrew-cz at Formula/cz.rb
#   4. users: `brew install H0BB5/cz/cz`
class Cz < Formula
  desc "Capture Claude Code commands/skills/plugins on the fly"
  homepage "https://github.com/H0BB5/cz"
  url "https://github.com/H0BB5/cz/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "REPLACE_WITH_SHA256_FROM_release.sh"
  license "MIT"
  version "0.2.0"

  depends_on "fzf" => :recommended

  def install
    bin.install "bin/cz"
    %w[cmdz sklz plgz].each { |n| bin.install_symlink bin/"cz" => n }
  end

  test do
    assert_match "cz #{version}", shell_output("#{bin}/cz --version")
    system bin/"cmdz", "smoke", "-m", "hello", "--dir", testpath, "-y"
    assert_predicate testpath/".claude/commands/smoke.md", :exist?
  end
end
