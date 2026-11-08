# frozen_string_literal: true

# Runtime checks only.
# RBS and Steep already guarantee field presence and value types, so this
# file does not enumerate fields. Only invariants types cannot express remain.

RSpec.describe Wikinder::GitHub::Wiki do
  let(:path) { File.expand_path('../../../../yuukinder.wiki', __dir__) }
  let(:wiki_url) { 'https://github.com/yuuki7/yuukinder/wiki' }
  let(:wiki) { described_class.new(path, { wiki_url: }) }

  describe '#pages_data' do
    # Slugs are catalogue keys, so a duplicate would collide on the site.
    it 'returns entries with unique, non-empty slugs' do
      data = wiki.pages_data
      expect(data).not_to be_empty

      slugs = data.map { |entry| entry[:slug] }
      expect(slugs.uniq.size).to eq(slugs.size)
      expect(slugs.none?(&:empty?)).to be(true)
    end

    # A redirect is only useful when its target exists as a canonical page.
    it 'points every redirect at an existing page' do
      data = wiki.pages_data
      canonical = data.reject { |entry| entry[:redirect] }.map { |entry| entry[:slug] }

      data.select { |entry| entry[:redirect] }.each do |entry|
        expect(canonical).to include(entry[:target_slug])
      end
    end
  end

  describe '#site_data' do
    # Head is the incremental watermark, so it must be a commit SHA.
    it 'returns a site head as a commit SHA' do
      data = wiki.site_data
      expect(data[:head]).to match(/\A[0-9a-f]{40}\z/)
    end
  end
end
