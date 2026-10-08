require "rails_helper"
require "importmap/packager"

RSpec.describe GovukFrontendPackager do
  subject(:packager) { Class.new(Importmap::Packager) { prepend GovukFrontendPackager }.new }

  let(:imports) { { "govuk-frontend" => "https://ga.jspm.io/npm:govuk-frontend@6.5.1/dist/govuk/all.mjs" } }
  let(:response) { instance_double(Net::HTTPOK, code: "200", body: { map: { imports: } }.to_json) }

  before do
    allow(Net::HTTP).to receive(:post).and_return(response)
  end

  it "selects the complete distribution for the resolved version" do
    result = packager.import("govuk-frontend@6.5.1")

    expect(result[:imports]).to eq(
      "govuk-frontend" => "https://cdn.jsdelivr.net/npm/govuk-frontend@6.5.1/dist/govuk/govuk-frontend.min.js",
    )
  end

  context "with another package in the same update" do
    let(:imports) { super().merge("other" => "https://example.com/other.js") }

    it "leaves the other package unchanged" do
      expect(packager.import("govuk-frontend", "other")[:imports]["other"]).to eq("https://example.com/other.js")
    end
  end

  context "without a GOV.UK package" do
    let(:imports) { { "other" => "https://example.com/other.js" } }

    it "preserves normal importmap behaviour" do
      expect(packager.import("other")[:imports]).to eq(imports)
    end
  end

  context "when the resolved version cannot be identified" do
    let(:imports) { { "govuk-frontend" => "https://example.com/all.mjs" } }

    it "fails rather than selecting an unversioned bundle" do
      expect { packager.import("govuk-frontend") }.to raise_error(Importmap::Packager::Error, /Cannot resolve/)
    end
  end

  context "when the package cannot be resolved" do
    let(:response) { instance_double(Net::HTTPNotFound, code: "404") }

    it "preserves the unsuccessful result" do
      expect(packager.import("missing")).to be_nil
    end
  end
end
