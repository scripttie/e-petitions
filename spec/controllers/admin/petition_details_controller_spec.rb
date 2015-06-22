require 'rails_helper'

RSpec.describe Admin::PetitionDetailsController do

  let(:petition) { FactoryGirl.create(:sponsored_petition) }

  describe 'not logged in' do
    describe 'GET #show' do
      it 'redirects to the login page' do
        get :show, petition_id: petition.id
        expect(response).to redirect_to('https://petition.parliament.uk/admin/login')
      end
    end

    describe 'PATCH #update' do
      it 'redirects to the login page' do
        patch :update, petition_id: petition.id
        expect(response).to redirect_to('https://petition.parliament.uk/admin/login')
      end
    end
  end

  context 'logged in as moderator user but need to reset password' do
    let(:user) { FactoryGirl.create(:moderator_user, force_password_reset: true) }
    before { login_as(user) }

    describe 'GET #show' do
      it 'redirects to edit profile page' do
        get :show, petition_id: petition.id
        expect(response).to redirect_to("https://petition.parliament.uk/admin/profile/#{user.id}/edit")
      end
    end

    describe 'PATCH #update' do
      it 'redirects to edit profile page' do
        patch :update, petition_id: petition.id
        expect(response).to redirect_to("https://petition.parliament.uk/admin/profile/#{user.id}/edit")
      end
    end
  end

  describe 'logged in as moderator user' do
    let(:user) { FactoryGirl.create(:moderator_user) }
    before { login_as(user) }

    describe 'GET #show' do
      shared_examples_for 'viewing a petition in the correct state' do
        it 'fetches the requested petition' do
          get :show, petition_id: petition.id
          expect(assigns(:petition)).to eq petition
        end

        it 'responds successfully and renders the petition_details/show template' do
          get :show, petition_id: petition.id
          expect(response).to be_success
          expect(response).to render_template('petition_details/show')
        end
      end

      describe 'for a sponsored petition' do
        it_behaves_like 'viewing a petition in the correct state'
      end

      describe 'for a pending petition' do
        before { petition.update_column(:state, Petition::PENDING_STATE) }
        it_behaves_like 'viewing a petition in the correct state'
      end

      describe 'for a validated petition' do
        before { petition.update_column(:state, Petition::VALIDATED_STATE) }
        it_behaves_like 'viewing a petition in the correct state'
      end

      shared_examples_for 'trying to view a petition in the wrong state' do
        it 'raises a 404 error' do
          expect {
            get :show, petition_id: petition.id
          }.to raise_error ActiveRecord::RecordNotFound
        end
      end

      describe 'for an open petition' do
        before { petition.update_column(:state, Petition::OPEN_STATE) }
        it_behaves_like 'trying to view a petition in the wrong state'
      end

      describe 'for a rejected petition' do
        before { petition.update_column(:state, Petition::REJECTED_STATE) }
        it_behaves_like 'trying to view a petition in the wrong state'
      end

      describe 'for a hidden petition' do
        before { petition.update_column(:state, Petition::HIDDEN_STATE) }
        it_behaves_like 'trying to view a petition in the wrong state'
      end
    end

    describe 'PATCH #update' do
      let(:petition) { FactoryGirl.create(:sponsored_petition, action: 'Old action', background: 'Old background', additional_details: 'Old additional details') }

      def do_update
        patch :update,
              petition_id: petition.id,
              petition: petition_attributes
      end

      describe 'allowed params' do
        it { should permit(:action, :background, :additional_details).for(:update, params: { petition_id: petition.id }) }
      end

      describe 'with valid params' do
        let(:petition_attributes) do
          {
              action: 'New action',
              background: 'New background',
              additional_details: 'New additional_details'
          }
        end

        shared_examples_for 'updating a petition in the correct state' do
          it 'redirects to the edit petition page' do
            do_update
            petition.reload
            expect(response).to redirect_to"https://petition.parliament.uk/admin/petitions/#{petition.id}"
          end

          it 'updates the petition' do
            do_update
            petition.reload
            expect(petition).to be_present
            expect(petition.action).to eq('New action')
            expect(petition.background).to eq('New background')
            expect(petition.additional_details).to eq('New additional_details')
          end
        end

        describe 'for a sponsored petition' do
          it_behaves_like 'updating a petition in the correct state'
        end

        describe 'for a pending petition' do
          before { petition.update_column(:state, Petition::PENDING_STATE) }
          it_behaves_like 'updating a petition in the correct state'
        end

        describe 'for a validated petition' do
          before { petition.update_column(:state, Petition::VALIDATED_STATE) }
          it_behaves_like 'updating a petition in the correct state'
        end
      end

      describe 'with invalid params' do
        let(:petition_attributes) do
          {
              action: '',
              background: '',
              additional_details: 'Blah'
          }
        end

        shared_examples_for 'updating a petition in the correct state' do
          it 'renders the petition_details/show template again' do
            do_update
            expect(response).to be_success
            expect(response).to render_template('petition_details/show')
          end
        end

        describe 'for a sponsored petition' do
          it_behaves_like 'updating a petition in the correct state'
        end

        describe 'for a pending petition' do
          before { petition.update_column(:state, Petition::PENDING_STATE) }
          it_behaves_like 'updating a petition in the correct state'
        end

        describe 'for a validated petition' do
          before { petition.update_column(:state, Petition::VALIDATED_STATE) }
          it_behaves_like 'updating a petition in the correct state'
        end
      end
    end
  end
end
