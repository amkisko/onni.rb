# frozen_string_literal: true

require "tmpdir"
require_relative "../../usr/lib/release_version_check"

RSpec.describe ReleaseVersionCheck do
  def write_changelog(content)
    path = File.join(Dir.mktmpdir, "CHANGELOG.md")
    File.write(path, content)
    path
  end

  describe ".changelog_notes_for" do
    it "returns the body under the matching version heading" do
      path = write_changelog(<<~MARKDOWN)
        # CHANGELOG

        ## Unreleased

        ## 1.0.0 (2026-11-13)

        - First change
        - Second change

        ## 0.1.3 (2026-11-12)

        - Older change
      MARKDOWN

      expect(described_class.changelog_notes_for("1.0.0", path: path)).to eq(
        "- First change\n- Second change\n"
      )
    end

    it "matches Keep a Changelog bracket headings" do
      path = write_changelog(<<~MARKDOWN)
        ## [1.2.3] - 2026-10-27

        - Bracketed notes
      MARKDOWN

      expect(described_class.changelog_notes_for("1.2.3", path: path)).to eq("- Bracketed notes\n")
    end

    it "returns nil when the version heading is absent" do
      path = write_changelog("## 0.1.0\n\n- Only this\n")

      expect(described_class.changelog_notes_for("9.9.9", path: path)).to be_nil
    end
  end

  describe ".require_changelog_notes!" do
    it "returns stripped notes for a present version section" do
      path = write_changelog(<<~MARKDOWN)
        ## 1.0.0

        - Ship it
      MARKDOWN

      expect(described_class.require_changelog_notes!(version: "1.0.0", path: path)).to eq("- Ship it")
    end

    it "aborts when the version section has no notes" do
      path = write_changelog(<<~MARKDOWN)
        ## 1.0.0

        ## 0.1.0

        - Prior
      MARKDOWN

      expect do
        described_class.require_changelog_notes!(version: "1.0.0", path: path)
      end.to raise_error(SystemExit)
    end
  end

  describe ".ls_remote_has_tag?" do
    it "is true when ls-remote lists the exact tag ref" do
      output = "941b50e7d064f441622099a7de50c0a49086ff2d\trefs/tags/1.0.1\n"

      expect(described_class.ls_remote_has_tag?(output, "1.0.1")).to be(true)
    end

    it "is true for annotated tag peeled refs" do
      output = <<~TEXT
        abc123\trefs/tags/1.0.1
        def456\trefs/tags/1.0.1^{}
      TEXT

      expect(described_class.ls_remote_has_tag?(output, "1.0.1")).to be(true)
    end

    it "is false when the tag is absent" do
      output = "941b50e7d064f441622099a7de50c0a49086ff2d\trefs/tags/1.0.0\n"

      expect(described_class.ls_remote_has_tag?(output, "1.0.1")).to be(false)
    end

    it "does not match a longer tag name prefix" do
      output = "941b50e7d064f441622099a7de50c0a49086ff2d\trefs/tags/1.0.10\n"

      expect(described_class.ls_remote_has_tag?(output, "1.0.1")).to be(false)
    end
  end

  describe ".continue_after_tag_push?" do
    it "continues when push succeeds" do
      expect(described_class.continue_after_tag_push?(push_ok: true, remote_tag_present: false)).to be(true)
    end

    it "continues when push fails but the GitHub-facing tag is present" do
      expect(described_class.continue_after_tag_push?(push_ok: false, remote_tag_present: true)).to be(true)
    end

    it "stops when push fails and the tag is missing on the fetch remote" do
      expect(described_class.continue_after_tag_push?(push_ok: false, remote_tag_present: false)).to be(false)
    end
  end
end
