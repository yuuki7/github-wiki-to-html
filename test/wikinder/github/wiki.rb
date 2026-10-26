# frozen_string_literal: true

RSpec.describe Wikinder::GitHub::Wiki do
  let(:path) { File.expand_path('../../../../yuukinder.wiki', __dir__) }

  describe '#to_json' do
    it 'returns JSON with title, slug, and html' do
      json = JSON.parse(described_class.new(path).to_json, symbolize_names: true)
      expect(json).to all(include(:title, :slug, :html))
    end
  end
end
