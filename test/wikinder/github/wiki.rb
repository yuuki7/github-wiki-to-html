# frozen_string_literal: true

# Runtime checks only.
# RBS and Steep already guarantee field presence and value types, so this
# file does not enumerate fields. Only invariants types cannot express remain.

require_relative '../../spec_helper'
require 'tmpdir'
require 'yaml'

RSpec.describe Wikinder::GitHub::Wiki do
  let(:target) { Dir.mktmpdir('content') }

  # Creates a fresh fixture wiki with a single seeded commit, runs a block
  # against it, then removes it.
  def with_seeded_wiki
    path = Dir.mktmpdir('wiki')
    begin
      FixtureWiki.build(path)
      yield described_class.new(path, fixture_options(unlisted_pages: Set[]))
    ensure
      FileUtils.remove_entry(path)
    end
  end

  after do
    FileUtils.rm_rf(target)
  end

  def fixture_options(ungenerated_pages: Set['Home', 'README', 'LICENSE', 'META', '_Footer'],
                      unlisted_pages: Set[],
                      ignore_meta: false)
    { ungenerated_pages:, unlisted_pages:, ignore_meta: }
  end

  describe '#build' do
    # Slugs are catalogue keys, so a duplicate would collide on the site.
    it 'writes pages with unique, non-empty slugs' do
      with_seeded_wiki do |wiki|
        wiki.build(target)
        slugs = Dir.glob(File.join(target, '*.md')).map { |name| File.basename(name, '.md') }
        expect(slugs).not_to be_empty
        expect(slugs.uniq.size).to eq(slugs.size)
        expect(slugs.none?(&:empty?)).to be(true)
      end
    end

    # A redirect is only useful when its target exists as a canonical page.
    it 'points every redirect at an existing article' do
      with_seeded_wiki do |wiki|
        wiki.build(target)
        entries = Dir.glob(File.join(target, '*.md')).map { |name| File.read(name) }
        kinds = entries.map { |content| YAML.safe_load(content.split("---\n")[1]) }
        canonical = kinds.select { |d| d['kind'] == 'article' }.map { |d| d['slug'] }
        kinds.select { |d| d['kind'] == 'redirect' }.each do |d|
          expect(canonical).to include(d['target_slug'])
        end
      end
    end

    # The home page and footer are written as ordinary files.
    it 'writes home and footer sub-pages' do
      with_seeded_wiki do |wiki|
        wiki.build(target)
        %w[Home _Footer].each do |name|
          expect(File.exist?(File.join(target, "#{name}.md"))).to be(true)
        end
      end
    end

    # Every page must parse as YAML front matter followed by a body.
    it 'keeps the file shape valid' do
      with_seeded_wiki do |wiki|
        wiki.build(target)
        Dir.glob(File.join(target, '**/*.md')).each do |file|
          content = File.read(file)
          chunks = content.split("---\n", 3)
          expect(chunks.length).to be(3).or be(2)
          meta = YAML.safe_load(chunks[1])
          expect(meta).to be_a(Hash)
          expect(%w[article redirect special]).to include(meta['kind'])
          expect(meta['title']).to be_a(String)
        end
      end
    end

    # META.md is managed by this tool and must never become a page of
    # its own when the caller forgets to exclude it.
    it 'excludes META.md from output when no options are given' do
      path = Dir.mktmpdir('default-opts-wiki')
      target = Dir.mktmpdir('default-opts-content')
      begin
        FixtureWiki.build(path)
        described_class.new(path).build(target)
        expect(File.exist?(File.join(target, 'META.md'))).to be(false)
        expect(File.exist?(File.join(target, 'About.md'))).to be(true)
      ensure
        FileUtils.remove_entry(path)
        FileUtils.remove_entry(target)
      end
    end

    # A page containing invalid UTF-8 bytes must not abort the build.
    it 'replaces invalid bytes in .md content instead of crashing' do
      path = Dir.mktmpdir('utf8-wiki')
      out = Dir.mktmpdir('utf8-out')
      begin
        system('git', 'init', '-q', '--initial-branch=main', chdir: path)
        File.binwrite(File.join(path, 'page.md'), "before \xff\xfe after [[foo]]\n".b)
        system('git', 'add', '-A', chdir: path)
        system('git', '-c', 'user.email=t@e', '-c', 'user.name=t', 'commit', '-qm', 'bad utf8',
               chdir: path)

        expect { described_class.new(path, fixture_options(ignore_meta: true)).build(out) }
          .not_to raise_error
        expect(File.read(File.join(out, 'page.md'), mode: 'rb')).to include("\uFFFD".b)
      ensure
        FileUtils.remove_entry(path)
        FileUtils.remove_entry(out)
      end
    end

    # A failing page must not leave any files behind in the output directory.
    it 'writes nothing when a page fails to render' do
      path = Dir.mktmpdir('atomic-wiki')
      out = Dir.mktmpdir('atomic-out')
      begin
        system('git', 'init', '-q', '--initial-branch=main', chdir: path)
        File.write(File.join(path, 'page.md'), "body\n")
        system('git', 'add', '-A', chdir: path)
        system('git', '-c', 'user.email=t@e', '-c', 'user.name=t', 'commit', '-qm', 'content',
               chdir: path)
        allow(Wikinder::GitHub::Wiki::Tags).to receive(:render).and_raise(StandardError, 'boom')

        expect { described_class.new(path, { ungenerated_pages: Set[], unlisted_pages: Set[] }).build(out) }
          .to raise_error(/could not render page page\.md/)
        expect(Dir.children(out)).to be_empty
      ensure
        FileUtils.remove_entry(path)
        FileUtils.remove_entry(out)
      end
    end

    # An author name containing a pipe must round-trip through META.md.
    it 'round-trips an author name containing a pipe' do
      scratch = Dir.mktmpdir('pipe-author-wiki')
      out = Dir.mktmpdir('pipe-author-out')
      begin
        system('git', 'init', '-q', '--initial-branch=main', chdir: scratch)
        File.write(File.join(scratch, 'page.md'), "text\n")
        system('git', 'add', '-A', chdir: scratch)
        system({ 'GIT_AUTHOR_NAME' => 'O-kun|Chan', 'GIT_COMMITTER_NAME' => 'O-kun|Chan' },
               'git', '-c', 'user.email=t@e', 'commit', '-qm', 'pipe author', chdir: scratch)

        described_class.new(scratch, { ungenerated_pages: Set[], unlisted_pages: Set[] }).build(out)
        meta_path = File.join(scratch, 'META.md')
        expect(File.read(meta_path)).to include('O-kun\|Chan')

        described_class.new(scratch, { ungenerated_pages: Set[], unlisted_pages: Set[] }).build(out)
        rows = Wikinder::GitHub::Wiki::Meta.load(Pathname(meta_path))
        expect(rows['page'][:author]).to eq('O-kun|Chan')
      ensure
        FileUtils.remove_entry(scratch)
        FileUtils.remove_entry(out)
      end
    end

    # --ignore-meta exercises the git-history fallback for authorship metadata.
    it 'derives metadata from git history when META.md is ignored' do
      path = Dir.mktmpdir('ignored-wiki')
      built_target = Dir.mktmpdir('ignored-content')
      begin
        FixtureWiki.build(path)
        described_class.new(path, fixture_options(ignore_meta: true)).build(built_target)
        article = Dir.glob(File.join(built_target, '*.md'))
                     .map { |name| YAML.safe_load(File.read(name).split("---\n")[1]) }
                     .find { |meta| meta['kind'] == 'article' }
        expect(article['creation_date']).to match(/\A\d{4}-\d{2}-\d{2}T/)
        expect(article['modified_date']).to match(/\A\d{4}-\d{2}-\d{2}T/)
        expect(article['author']).to be_a(String)
        expect(article['author']).not_to be_empty
      ensure
        FileUtils.remove_entry(path)
        FileUtils.remove_entry(built_target)
      end
    end
  end

  describe '.render' do
    # Wiki link format should be a standard Markdown link when outside raw HTML.
    it 'emits Markdown links outside raw HTML blocks' do
      output = Wikinder::GitHub::Wiki::Tags.render('body [[Bear-arithmetic]] end')
      expect(output).to include('[Bear-arithmetic](/Bear-arithmetic)')
    end

    # Raw HTML blocks keep anchors because Markdown does not run inside them.
    it 'emits raw HTML anchors inside HTML blocks' do
      output = Wikinder::GitHub::Wiki::Tags.render("<td>Founder of [[bear]]</td>\n")
      expect(output).to include('<a href="/bear">bear</a>')
    end

    # Wiki links ending in image extensions render as images, not links.
    it 'renders bare image references as Markdown images' do
      output = Wikinder::GitHub::Wiki::Tags.render('![[kuma.png]]')
      expect(output).to include('![kuma](kuma.png)')
    end

    # Regression: a wikilink used to lose its final byte when it sat at the
    # very end of a raw HTML block, so it was left verbatim instead of
    # becoming an anchor link.
    it 'rewrites wikilinks at the end of a raw HTML block' do
      output = Wikinder::GitHub::Wiki::Tags.render("<div>\nSee [[Foo]]\n")
      expect(output).to include('<a href="/Foo">Foo</a>')
    end

    it 'rewrites wikilinks at the end of a raw HTML block without trailing newline' do
      output = Wikinder::GitHub::Wiki::Tags.render("<div>\nSee [[Foo]]")
      expect(output).to include('<a href="/Foo">Foo</a>')
    end

    # Wikilinks inside comments/script/style/tags are literal, never rewritten.
    it 'does not rewrite wikilinks inside HTML comments' do
      output = Wikinder::GitHub::Wiki::Tags.render("<!-- keep [[keep]] -->\n[[Link]]\n")
      expect(output).to include('<!-- keep [[keep]] -->')
      expect(output).to include('[Link](/Link)')
    end

    it 'does not rewrite wikilinks inside script bodies' do
      output = Wikinder::GitHub::Wiki::Tags.render("<script>\nvar x = '[[keep]]';\n</script>\n[[Link]]\n")
      expect(output).to include("var x = '[[keep]]';")
      expect(output).to include('[Link](/Link)')
    end

    it 'does not rewrite wikilinks inside tag attributes' do
      output = Wikinder::GitHub::Wiki::Tags.render("<a href=\"[[keep]]\">text [[Link]]</a>\n")
      expect(output).to include('href="[[keep]]"')
      expect(output).to include('[Link](/Link)')
    end

    # The .md extension must not leak into the link target when an anchor is present.
    it 'strips the .md suffix before keeping the anchor' do
      output = Wikinder::GitHub::Wiki::Tags.render('[[Foo.md#anchor]]')
      expect(output).to include('[Foo.md#anchor](/Foo#anchor)')
    end

    # Pipe form: image path on the left (Gollum convention), caption on the right.
    it 'treats pipe images as path-plus-caption' do
      output = Wikinder::GitHub::Wiki::Tags.render('[[kuma.png|caption here]]')
      expect(output).to include('![caption here](kuma.png)')
    end

    # Wiki image extension detection in HTML blocks renders raw HTML images.
    it 'renders pipe images inside raw HTML as HTML images' do
      output = Wikinder::GitHub::Wiki::Tags.render("<td>![[kuma.png]]</td>\n")
      expect(output).to include('<img src="kuma.png" alt="kuma">')
    end

    # Regression anchors: raw HTML tables keep reading as anchors.
    it 'renders wikilinks as raw HTML anchors inside table cells' do
      output = Wikinder::GitHub::Wiki::Tags.render("<td>Founder of [[bear]]</td>\n")
      expect(output).to include('<a href="/bear">bear</a>')
    end

    # A rename history with multiple chained renames must restore every ancestor alias.
    it 'restores rename aliases across multiple levels' do
      scratch = Dir.mktmpdir('chain-wiki')
      begin
        system('git', 'init', '-q', chdir: scratch)
        File.write(File.join(scratch, 'page-a.md'), "content\n")
        File.write(File.join(scratch, 'content.md'), "content\n")
        system('git', 'add', '-f', '.', chdir: scratch)
        system('git', '-c', 'user.email=t@e', '-c', 'user.name=t', 'commit', '-qm', 'initial', chdir: scratch)
        system('git', 'mv', 'page-a.md', 'page-b.md', chdir: scratch)
        system('git', '-c', 'user.email=t@e', '-c', 'user.name=t', 'commit', '-qm', 'rename a to b', chdir: scratch)
        system('git', 'mv', 'page-b.md', 'page-c.md', chdir: scratch)
        system('git', '-c', 'user.email=t@e', '-c', 'user.name=t', 'commit', '-qm', 'rename b to c', chdir: scratch)
        out = Dir.mktmpdir('chain-out')
        begin
          described_class.new(scratch, { ungenerated_pages: Set[], unlisted_pages: Set[] })
                         .build(out)
          row_line = File.readlines(File.join(scratch, 'META.md')).find { |l| l.include?('[[page c]]') }
          expect(row_line).to include('page a')
          expect(row_line).to include('page b')
        ensure
          FileUtils.remove_entry(out)
        end
      ensure
        FileUtils.remove_entry(scratch)
      end
    end

    # Rename chains must keep the original creation date, not the rename date.
    it 'derives creation_date from the original file, following renames' do
      scratch = Dir.mktmpdir('chain-bounds-wiki')
      begin
        system('git', 'init', '-q', chdir: scratch)
        File.write(File.join(scratch, 'initial.md'), "first draft\n")
        system('git', 'add', '-f', '.', chdir: scratch)
        system({ 'GIT_COMMITTER_DATE' => '2020-01-01T00:00:00Z' }, 'git',
               '-c', 'user.email=t@e', '-c', 'user.name=t', 'commit', '-qm', 'first',
               chdir: scratch)
        system('git', 'mv', 'initial.md', 'renamed.md', chdir: scratch)
        system({ 'GIT_COMMITTER_DATE' => '2030-01-01T00:00:00Z' }, 'git',
               '-c', 'user.email=t@e', '-c', 'user.name=t', 'commit', '-qm', 'rename',
               chdir: scratch)
        out = Dir.mktmpdir('chain-bounds-out')
        begin
          described_class.new(scratch, { ungenerated_pages: Set[], unlisted_pages: Set[], ignore_meta: true })
                         .build(out)
          row_line = File.readlines(File.join(scratch, 'META.md')).find { |l| l.include?('[[renamed]]') }
          expect(row_line).to include('2020-01-01')
        ensure
          FileUtils.remove_entry(out)
        end
      ensure
        FileUtils.remove_entry(scratch)
      end
    end
  end

  describe '#redirects' do
    let(:scratch) { Dir.mktmpdir('redirect-wiki') }

    after do
      FileUtils.remove_entry(scratch)
    end

    # Replaces the empty aliases cell of the given [[Title]] row with
    # +alias_text+. Raises when the row is missing or its aliases cell is
    # not empty, so a shape change in the fixture is never silently skipped.
    def set_alias(title, alias_text)
      meta_path = File.join(scratch, 'META.md')
      lines = File.readlines(meta_path).map(&:chomp)
      index = lines.find_index { |line| line.include?("[[#{title}]]") }
      raise "no row for [[#{title}]]" if index.nil?

      updated = lines[index].sub(/\|\s*\|\z/, "| #{alias_text} |")
      raise "aliases cell is not empty on row [[#{title}]]: #{lines[index]}" if updated == lines[index]

      lines[index] = updated
      File.write(meta_path, "#{lines.join("\n")}\n")
    end

    # A stale name from a rename must never shadow an existing article.
    it 'keeps the existing article when an alias collides with its slug' do
      FixtureWiki.build(scratch)
      set_alias('Japanese page', 'About')

      target = Dir.mktmpdir('content')
      described_class.new(scratch, fixture_options(unlisted_pages: Set[])).build(target)

      expect(File.read(File.join(target, 'About.md'))).to include('kind: article')
      row = File.readlines(File.join(scratch, 'META.md')).find { |l| l.include?('[[Japanese page]]') }
      expect(row).not_to include('About')
      FileUtils.remove_entry(target)
    end

    # Same priority applies to the special pages.
    it 'keeps the special Home page when an alias collides with it' do
      FixtureWiki.build(scratch)
      set_alias('Japanese page', 'Home')

      target = Dir.mktmpdir('content')
      described_class.new(scratch, fixture_options(unlisted_pages: Set[])).build(target)

      expect(File.read(File.join(target, 'Home.md'))).to include('kind: special')
      row = File.readlines(File.join(scratch, 'META.md')).find { |l| l.include?('[[Japanese page]]') }
      expect(row).not_to include('Home')
      FileUtils.remove_entry(target)
    end

    # Hand-curated alias must be dropped through the incremental keep path
    # too, not only through a full rebuild.
    it 'prunes a hand-curated colliding alias via the incremental keep path' do
      FixtureWiki.build(scratch)
      target = Dir.mktmpdir('content')
      described_class.new(scratch, fixture_options(unlisted_pages: Set[])).build(target)
      base_sha = Dir.chdir(scratch) { `git rev-parse HEAD`.strip }

      set_alias('Japanese page', 'About')

      target2 = Dir.mktmpdir('content2')
      wiki = described_class.new(scratch, fixture_options(unlisted_pages: Set[]).merge(prev_head: base_sha))
      wiki.build(target2)
      expect(wiki.send(:diff_paths, base_sha)).to eq([]) # provenance: incremental keep path ran
      row = File.readlines(File.join(scratch, 'META.md')).find { |l| l.include?('[[Japanese page]]') }
      expect(row).not_to include('About')
      expect(File.read(File.join(target2, 'About.md'))).to include('kind: article')
      FileUtils.remove_entry(target)
      FileUtils.remove_entry(target2)
    end

    # A non-colliding alias is still materialised as a redirect.
    it 'writes a redirect for a free alias' do
      FixtureWiki.build(scratch)
      set_alias('Japanese page', 'Timeline of yuuki')

      target = Dir.mktmpdir('content')
      described_class.new(scratch, fixture_options(unlisted_pages: Set[])).build(target)

      expect(File.read(File.join(target, 'Timeline-of-yuuki.md'))).to include('kind: redirect')
      row = File.readlines(File.join(scratch, 'META.md')).find { |l| l.include?('[[Japanese page]]') }
      expect(row).to include('Timeline of yuuki')
      FileUtils.remove_entry(target)
    end
  end

  describe '#robustness' do
    let(:scratch) { Dir.mktmpdir('robust-wiki') }

    after do
      FileUtils.remove_entry(scratch)
    end

    def git(*args)
      raise "git failed: #{args.inspect}" unless system(
        'git', '-c', 'user.email=t@e', '-c', 'user.name=t', *args, chdir: scratch
      )
    end

    # GitHub Wiki is flat and does not support subdirectories, so nested
    # files are silently unsupported — no page, no asset, no error.
    it 'silently ignores pages and assets in subdirectories' do
      system('git', 'init', '-q', '--initial-branch=main', chdir: scratch)
      File.write(File.join(scratch, 'Root.md'), "page\n")
      FileUtils.mkdir_p(File.join(scratch, 'nested', 'deep'))
      File.write(File.join(scratch, 'nested', 'Nest.md'), "nested page\n")
      File.write(File.join(scratch, 'nested', 'deep', 'Deep.md'), "deep page\n")
      File.binwrite(File.join(scratch, 'nested', 'deep', 'image.png'), 'png'.b)
      git('add', '-A')
      git('commit', '-qm', 'nested content')

      target = Dir.mktmpdir('robust-out')
      begin
        expect { Wikinder::GitHub::Wiki.new(scratch, { ungenerated_pages: Set[], unlisted_pages: Set[] }).build(target) }
          .not_to output(/.+/).to_stderr
        expect(Dir.children(target).sort).to eq(['Root.md'])
        expect(Dir.children(target)).to all(satisfy { |name| !name.include?('/') })
      ensure
        FileUtils.remove_entry(target)
      end
    end

    # An alias claimed by two different pages names neither wrapper nor
    # redirect uniquely — it must be dropped from every claimant.
    it 'drops an alias claimed by two different pages, and warns' do
      FixtureWiki.build(scratch)
      meta_path = File.join(scratch, 'META.md')
      lines = File.readlines(meta_path).map(&:chomp)
      rows = lines.map do |line|
        if line.include?('[[About]]') || line.include?('[[Japanese page]]')
          line.sub(/\|\s*\|\z/, '| Shared |')
        else
          line
        end
      end
      File.write(meta_path, "#{rows.join("\n")}\n")

      target = Dir.mktmpdir('robust-out')
      begin
        expect { Wikinder::GitHub::Wiki.new(scratch, fixture_options(unlisted_pages: Set[])).build(target) }
          .to output(/claimed by/).to_stderr
        expect(File.exist?(File.join(target, 'Shared.md'))).to be(false)
        expect(File.read(File.join(scratch, 'META.md'))).not_to include('| Shared |')
      ensure
        FileUtils.remove_entry(target)
      end
    end

    # Aliases must never resolve outside the output directory.
    it 'drops an alias with path separators instead of escaping the output dir' do
      FixtureWiki.build(scratch)
      meta_path = File.join(scratch, 'META.md')
      lines = File.readlines(meta_path).map(&:chomp)
      rows = lines.map do |line|
        if line.include?('[[Japanese page]]')
          line.sub(/\|\s*\|\z/, '| ../escape |')
        else
          line
        end
      end
      File.write(meta_path, "#{rows.join("\n")}\n")

      target = Dir.mktmpdir('robust-out')
      begin
        expect { Wikinder::GitHub::Wiki.new(scratch, fixture_options(unlisted_pages: Set[])).build(target) }
          .to output(/unsafe alias/).to_stderr
        expect(File.exist?(File.join(target, '..', 'escape.md'))).to be(false)
        expect(File.read(File.join(scratch, 'META.md'))).not_to include('../escape')
      ensure
        FileUtils.remove_entry(target)
      end
    end
  end

  describe '#incremental sync' do
    let(:scratch) { Dir.mktmpdir('incr-wiki') }

    before do
      system('git', 'init', '-q', '--initial-branch=main', chdir: scratch) or raise 'git init failed'
      File.write(File.join(scratch, 'Home.md'), "Home contents\n")
      File.write(File.join(scratch, 'history.md'), "initial content\n")
      system('git', 'add', '-f', '.', chdir: scratch)
      system({ 'GIT_AUTHOR_DATE' => '2020-01-01T00:00:00Z', 'GIT_COMMITTER_DATE' => '2020-01-01T00:00:00Z' },
             'git', '-c', 'user.email=t@e', '-c', 'user.name=t', 'commit', '-qm', 'initial',
             chdir: scratch)
    end

    after do
      FileUtils.remove_entry(scratch)
    end

    def build(path, options = {})
      target = Dir.mktmpdir('content')
      wiki = Wikinder::GitHub::Wiki.new(path, { ungenerated_pages: Set['Home'], unlisted_pages: Set[] }
                                              .merge(options))
      wiki.build(target)
      target
    end

    it 'leaves META.md untouched when the repo is unchanged' do
      out1 = build(scratch)
      before_meta = File.read(File.join(scratch, 'META.md'))

      # The incremental path must diff the scratch repo's own HEAD against itself.
      base_sha = Dir.chdir(scratch) { `git rev-parse HEAD`.strip }
      wiki = described_class.new(scratch, { ungenerated_pages: Set['Home'], unlisted_pages: Set[] })
      expect(wiki.send(:diff_paths, base_sha)).to eq([])

      out2 = build(scratch, prev_head: base_sha)
      expect(File.read(File.join(scratch, 'META.md'))).to eq(before_meta)
      FileUtils.remove_entry(out1)
      FileUtils.remove_entry(out2)
    end

    # A reverted META.md must not erase curated fields on a rename.
    # After the revert, a fast-path build (prev_head == HEAD) sees a
    # renamed page with no matching row; it must recover the curated row
    # via rename history, not fall back to git-derived defaults.
    it 'restores curated fields when META.md is reverted to a pre-rename state' do
      meta_path = File.join(scratch, 'META.md')

      out1 = build(scratch)
      File.write(meta_path, File.read(meta_path).gsub(/(\[\[history\]\] \| )[^|]+/, '\\1curated-author'))
      curated = File.read(meta_path)
      system('git', '-c', 'user.email=t@e', '-c', 'user.name=t', 'add', '-f', 'META.md', chdir: scratch)
      system('git', '-c', 'user.email=t@e', '-c', 'user.name=t', 'commit', '-qm', 'curate author', chdir: scratch)

      system('git', 'mv', 'history.md', 'renamed-final.md', chdir: scratch)
      system('git', '-c', 'user.email=t@e', '-c', 'user.name=t', 'commit', '-qm', 'rename history to renamed-final',
             chdir: scratch)

      # Simulate a META.md revert: the working tree goes back to the
      # curated snapshot (rows keyed by the old slug).
      File.write(meta_path, curated)

      base_sha = Dir.chdir(scratch) { `git rev-parse HEAD`.strip }
      out2 = build(scratch, prev_head: base_sha)
      row_line = File.readlines(meta_path).find { |line| line.include?('[[renamed final]]') }
      expect(row_line).to include('curated-author')   # hand-curated value survives
      expect(row_line).to include('2020-01-01')       # creation_date from git history
      expect(row_line).to include('history')          # rename alias recovered
      FileUtils.remove_entry(out1)
      FileUtils.remove_entry(out2)
    end

    it 'preserves hand-curated fields when the page is renamed' do
      out = build(scratch)
      meta_path = File.join(scratch, 'META.md')

      # Set a hand-curated author for the initial row, then rename the page.
      original = File.read(meta_path)
      updated = original.gsub(/(\[\[history\]\] \| )[^|]+/, '\\1curated-author')
      File.write(meta_path, updated)

      # The initial commit SHA of the scratch repo; passing it as prev_head
      # forces the incremental path (not a silent full rebuild).
      base_sha = Dir.chdir(scratch) { `git rev-parse HEAD`.strip }

      system('git', 'mv', 'history.md', 'renamed.md', chdir: scratch)
      system('git', 'add', '-f', '.', chdir: scratch)
      system({ 'GIT_AUTHOR_DATE' => '2024-06-15T00:00:00Z', 'GIT_COMMITTER_DATE' => '2024-06-15T00:00:00Z' },
             'git', '-c', 'user.email=t@e', '-c', 'user.name=t', 'commit', '-qm', 'rename history to renamed',
             chdir: scratch)

      # The incremental path must see a non-nil, non-empty delta since base_sha.
      # (nil would silently fall back to a full rebuild and defeat the test's intent.)
      wiki = described_class.new(scratch, { ungenerated_pages: Set['Home'], unlisted_pages: Set[] })
      expect(wiki.send(:diff_paths, base_sha)).to include('renamed.md')

      out2 = build(scratch, prev_head: base_sha)
      row_line = File.readlines(meta_path).find { |l| l.include?('[[renamed]]') }
      expect(row_line).to include('curated-author')  # hand-curated author kept
      expect(row_line).to include('2020-01-01')      # creation_date preserved
      FileUtils.remove_entry(out)
      FileUtils.remove_entry(out2)
    end
  end
end

RSpec.describe Wikinder::GitHub::Wiki::Meta do
  it 'round-trips cells containing pipes and backslashes' do
    line = '| [[French programmer]] | O-\|Chan | 2024-01-01T00:00:00Z | ' \
           '2024-01-01T00:00:00Z | en | ex<br>a\|b<br>z \\ |'
    row = described_class.parse_row(line)
    expect(row[:author]).to eq('O-|Chan')
    expect(row[:aliases]).to eq(['ex', 'a|b', 'z \\'])
    cells = [
      "[[#{described_class.escape_cell(row[:title])}]]",
      described_class.escape_cell(row[:author]),
      described_class.escape_cell(row[:creation_date]),
      described_class.escape_cell(row[:modified_date]),
      described_class.escape_cell(row[:language]),
      described_class.escape_cell(row[:aliases].join('<br>'))
    ]
    expect(cells).to eq([
                          '[[French programmer]]',
                          'O-\|Chan',
                          '2024-01-01T00:00:00Z',
                          '2024-01-01T00:00:00Z',
                          'en',
                          'ex<br>a\|b<br>z \\\\'
                        ])
  end

  it 'warns and skips rows with too few cells' do
    expect { described_class.parse_row('| [[x]] | |') }.to output(/too few cells/).to_stderr
    expect(described_class.parse_row('| [[x]] | |')).to be_nil
  end

  it 'warns when a row has no [[Title]] cell' do
    line = '| not-a-title | a | b | c | d | e |'
    expect { described_class.parse_row(line) }.to output(/Title/).to_stderr
    expect(described_class.parse_row(line)).to be_nil
  end

  it 'keeps the later row when a slug is duplicated, with a warning' do
    path = Dir.mktmpdir('dup-meta')
    begin
      File.write(File.join(path, 'META.md'), <<~MD)
        | [[page]] | t | d | d | en | |
        | [[page]] | t | d2 | d2 | en | curated |
      MD
      rows = nil
      expect { rows = described_class.load(Pathname(path) / 'META.md') }.to output(/duplicate row/).to_stderr
      expect(rows['page'][:aliases]).to eq(['curated'])
    ensure
      FileUtils.remove_entry(path)
    end
  end
end
