# frozen_string_literal: true

# Runtime checks only.
# RBS and Steep already guarantee field presence and value types, so this
# file does not enumerate fields. Only invariants types cannot express remain.

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

    # Pipe form: image path on the left (Gollum convention), caption on the right.
    it 'treats pipe images as path-plus-caption' do
      output = Wikinder::GitHub::Wiki::Tags.render('[[kuma.png|caption here]]')
      expect(output).to include('![caption here](kuma.png)')
    end

    # Wiki image extension detection in HTML blocks renders raw HTML images.
    it 'renders pipe images inside raw HTML as HTML images' do
      output = Wikinder::GitHub::Wiki::Tags.render("<td>![[kuma.png]]</td>\n")
      expect(output).to include('<img src="kuma.png" alt="kuma" />')
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
