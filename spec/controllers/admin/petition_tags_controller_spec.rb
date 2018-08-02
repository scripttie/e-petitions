require 'rails_helper'

RSpec.describe Admin::PetitionTagsController, type: :controller, admin: true do
  let!(:petition) { FactoryBot.create(:open_petition) }

  context "when not logged in" do
    describe "GET /admin/petitions/:petition_id/tags" do
      it "redirects to the login page" do
        get :show, petition_id: petition.id
        expect(response).to redirect_to("https://moderate.petition.parliament.uk/admin/login")
      end
    end

    describe "PATCH /admin/petitions/:petition_id/tags" do
      it "redirects to the login page" do
        patch :update, petition_id: petition.id
        expect(response).to redirect_to("https://moderate.petition.parliament.uk/admin/login")
      end
    end
  end

  context "when logged in as moderator user but need to reset password" do
    let(:user) { FactoryBot.create(:moderator_user, force_password_reset: true) }
    before { login_as(user) }

    describe "GET /admin/petitions/:petition_id/tags" do
      it "redirects to the edit profile page" do
        get :show, petition_id: petition.id
        expect(response).to redirect_to("https://moderate.petition.parliament.uk/admin/profile/#{user.id}/edit")
      end
    end

    describe "PATCH /admin/petitions/:petition_id/tags" do
      it "redirects to the edit profile page" do
        patch :update, petition_id: petition.id
        expect(response).to redirect_to("https://moderate.petition.parliament.uk/admin/profile/#{user.id}/edit")
      end
    end
  end

  context "when logged in as moderator user" do
    let(:user) { FactoryBot.create(:moderator_user) }
    before { login_as(user) }

    describe "GET /admin/petitions/:petition_id/tags" do
      before { get :show, petition_id: petition.id }

      it "returns 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the :show template" do
        expect(response).to render_template("admin/petitions/show")
      end
    end

    describe "PATCH /admin/petitions/:petition_id/tags" do
      before { patch :update, petition_id: petition.id, petition: params }

      context "and the params are invalid" do
        let :params do
          { tags: ["999"] }
        end

        it "returns 200 OK" do
          expect(response).to have_http_status(:ok)
        end

        it "renders the :show template" do
          expect(response).to render_template("admin/petitions/show")
        end
      end

      context "and the params are valid" do
        let :params do
          { tags: [""] }
        end

        it "redirects to the petition page" do
          expect(response).to redirect_to("https://moderate.petition.parliament.uk/admin/petitions/#{petition.id}")
        end

        it "sets the flash notice message" do
          expect(flash[:notice]).to eq("Petition has been successfully updated")
        end
      end
    end
  end
end
