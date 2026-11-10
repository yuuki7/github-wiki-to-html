# frozen_string_literal: true

# Runtime checks only.
# RBS and Steep already guarantee field presence and value types, so this
# file does not enumerate fields. Only invariants types cannot express remain.

require 'tmpdir'
require 'yaml'

RSpec.describe Wikinder::GitHub::Wiki do
  let(:path) { File.expand_path('../../../../yuukinder.wiki', __dir__) }
  let(:ungenerated_pages) { Set['Home', 'README', 'LICENSE', 'META', '_Footer'] }
  let(:unlisted_pages) { Set['Wikinder', 'Wikinder-Japan'] }
  let(:wiki) do
    options = { ungenerated_pages:, unlisted_pages: }
    described_class.new(path, options)
  end
  let(:target) { Dir.mktmpdir('content') }

  after do
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
  end
end
