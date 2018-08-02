require 'rails_helper'

RSpec.describe PageTitleHelper, type: :helper do
  before do
    I18n.backend.store_translations(:fr, translations)
  end

  around do |example|
    begin
      locale, I18n.locale = I18n.locale, :fr
      example.run
    ensure
      I18n.locale = locale
    end
  end

  let :translations do
    { page_titles: {
        default: "Une pétition au Parlement",
        pages: {
          index: "Une pétition au Parlement - vers le bas avec ce genre de chose"
        },
        local_petitions: {
          index: {
            zero: "Local pour vous - Pétitions",
            one: "Pétitions à %{postcode}"
          },
          show: "Pétitions à %{constituency}"
        },
        petitions: {
          default: "Voir toutes les pétitions",
          show: "%{petition} - Pétitions"
        },
        sponsors: {
          new: "La pétition de soutien %{creator} - Pétitions"
    }}}
  end

  describe "#page_title" do
    context "when the controller and action keys exist" do
      before do
        params[:controller] = "pages"
        params[:action] = "index"
      end

      it "uses the key 'page_titles.controller.action'" do
        expect(helper.page_title).to eq("Une pétition au Parlement - vers le bas avec ce genre de chose")
      end
    end

    context "when the action key doesn't exist" do
      before do
        params[:controller] = "petitions"
        params[:action] = "unknown"
      end

      it "uses the key 'page_titles.controller.default'" do
        expect(helper.page_title).to eq("Voir toutes les pétitions")
      end
    end

    context "when the controller and action keys don't exist" do
      before do
        params[:controller] = "unknown"
        params[:action] = "unknown"
      end

      it "uses the key 'page_titles.default'" do
        expect(helper.page_title).to eq("Une pétition au Parlement")
      end
    end

    context "when there is a petition assigned" do
      let(:creator) { double(:signature, name: "Jacques Cousteau") }

      let(:petition) do
        double(:petition,
          creator: creator,
          action: "Ban devoirs pour les enfants de l'école primaire"
        )
      end

      before do
        assign("petition", petition)
      end

      it "the petition action is available for interpolation" do
        params[:controller] = "petitions"
        params[:action] = "show"

        expect(helper.page_title).to eq("Ban devoirs pour les enfants de l'école primaire - Pétitions")
      end

      it "the petition creator is available for interpolation" do
        params[:controller] = "sponsors"
        params[:action] = "new"

        expect(helper.page_title).to eq("La pétition de soutien Jacques Cousteau - Pétitions")
      end
    end

    context "when on the local petitions index page without a postcode" do
      before do
        params[:controller] = "local_petitions"
        params[:action] = "index"
      end

      it "uses the :zero option from the translation" do
        expect(helper.page_title).to eq("Local pour vous - Pétitions")
      end
    end

    context "when on the local petitions index page with a postcode" do
      let(:postcode) { "XM45HQ" }

      before do
        params[:controller] = "local_petitions"
        params[:action] = "index"
        assign('postcode', postcode)
      end

      it "the formatted postcode is available for interpolation" do
        expect(helper.page_title).to eq("Pétitions à XM4 5HQ")
      end
    end

    context "when on the local petitions show page" do
      let(:constituency) { double(:constituency, name: "Paris") }

      before do
        params[:controller] = "local_petitions"
        params[:action] = "show"
        assign('constituency', constituency)
      end

      it "the constituency name is available for interpolation" do
        expect(helper.page_title).to eq("Pétitions à Paris")
      end
    end
  end
end
