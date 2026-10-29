# frozen_string_literal: true

RSpec.describe Wikinder::GitHub::Wiki do
  let(:path) { File.expand_path('../../../../yuukinder.wiki', __dir__) }

  describe '#pages_data' do
    it 'returns array with title, slug, html, toc, creation_date' do
      data = described_class.new(path).pages_data
      expect(data).to all(include(:title, :slug, :html, :toc, :creation_date))
    end
  end

  describe '#site_data' do
    it 'returns hash with footer' do
      data = described_class.new(path).site_data
      expect(data).to include(:footer)
    end
  end
end
