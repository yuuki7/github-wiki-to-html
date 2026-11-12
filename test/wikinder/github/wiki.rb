# frozen_string_literal: true

# Runtime checks only.
# RBS and Steep already guarantee field presence and value types, so this
# file does not enumerate fields. Only invariants types cannot express remain.

require 'tmpdir'
require 'yaml'

RSpec.describe Wikinder::GitHub::Wiki do
  let(:source_path) { File.expand_path('../../../../yuukinder.wiki', __dir__) }
  # Tests operate on a throwaway copy of the wiki so that META.md updates
  # do not touch the real working tree.
  let(:path) { Dir.mktmpdir('wiki') }
  let(:ungenerated_pages) { Set['Home', 'README', 'LICENSE', 'META', '_Footer'] }
  let(:unlisted_pages) { Set['Wikinder', 'Wikinder-Japan'] }
  let(:default_options) { { ungenerated_pages:, unlisted_pages: } }
  let(:wiki) { described_class.new(path, default_options) }
  let(:ignore_meta_wiki) { described_class.new(path, default_options.merge(ignore_meta: true)) }
  let(:target) { Dir.mktmpdir('content') }

  before do
    FileUtils.cp_r(File.join(source_path, '.'), path)
  end

  after do
    FileUtils.remove_entry(path)
    FileUtils.remove_entry(target)
  end

  describe '#build' do
    # Slugs are catalogue keys, so a duplicate would collide on the site.
    it 'writes pages with unique, non-empty slugs' do
      wiki.build(target)
      slugs = Dir.glob(File.join(target, '*.md')).map { |name| File.basename(name, '.md') }
      expect(slugs).not_to be_empty
      expect(slugs.uniq.size).to eq(slugs.size)
      expect(slugs.none?(&:empty?)).to be(true)
    end

    # A redirect is only useful when its target exists as a canonical page.
    it 'points every redirect at an existing article' do
      wiki.build(target)
      entries = Dir.glob(File.join(target, '*.md')).map { |name| File.read(name) }
      kinds = entries.map { |content| YAML.safe_load(content.split("---\n")[1]) }
      canonical = kinds.select { |d| d['kind'] == 'article' }.map { |d| d['slug'] }
      kinds.select { |d| d['kind'] == 'redirect' }.each do |d|
        expect(canonical).to include(d['target_slug'])
      end
    end

    # The home page and footer are written as ordinary files.
    it 'writes home and footer sub-pages' do
      wiki.build(target)
      %w[Home _Footer].each do |name|
        expect(File.exist?(File.join(target, "#{name}.md"))).to be(true)
      end
    end

    # Every page must parse as YAML front matter followed by a body.
    it 'keeps the file shape valid' do
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

    # --ignore-meta exercises the git-history fallback for authorship metadata.
    it 'derives metadata from git history when META.md is ignored' do
      ignore_meta_wiki.build(target)
      article = Dir.glob(File.join(target, '*.md'))
                   .map { |name| YAML.safe_load(File.read(name).split("---\n")[1]) }
                   .find { |meta| meta['kind'] == 'article' }
      expect(article['creation_date']).to match(/\A\d{4}-\d{2}-\d{2}T/)
      expect(article['modified_date']).to match(/\A\d{4}-\d{2}-\d{2}T/)
      expect(article['author']).to be_a(String)
      expect(article['author']).not_to be_empty
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
end
