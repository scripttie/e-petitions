require 'rails_helper'

RSpec.describe MarkdownHelper, type: :helper do
  describe "#markdown_to_html" do
    it "converts markdown to html" do
      expect(helper.markdown_to_html("## Petitions: UK Government and Parliament")).to eq(%[<h2>Petitions: UK Government and Parliament</h2>\n])
    end

    it "autolinks urls" do
      expect(helper.markdown_to_html("www.example.com")).to eq(%[<p><a href="http://www.example.com">www.example.com</a></p>\n])
    end
  end

  describe "#markdown_to_text" do
    it "converts markdown to text" do
      expect(helper.markdown_to_text("## Petitions: UK Government and Parliament")).to eq(%[Petitions: UK Government and Parliament\n])
    end

    it "autolinks urls" do
      expect(helper.markdown_to_text("www.example.com")).to eq(%[www.example.com (http://www.example.com)\n])
    end
  end
end
