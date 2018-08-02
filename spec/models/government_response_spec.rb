require 'rails_helper'

RSpec.describe GovernmentResponse, type: :model do
  it "has a valid factory" do
    expect(FactoryBot.build(:government_response)).to be_valid
  end

  describe "associations" do
    it { is_expected.to belong_to(:petition).touch(true) }
  end

  describe "indexes" do
    it { is_expected.to have_db_index([:petition_id]).unique }
  end

  describe "validations" do
    subject { FactoryBot.build(:government_response) }

    it { is_expected.to validate_presence_of(:petition) }
    it { is_expected.to validate_presence_of(:summary) }
    it { is_expected.to validate_length_of(:summary).is_at_most(200) }
    it { is_expected.to validate_length_of(:details).is_at_most(6000) }
  end

  describe "callbacks" do
    describe "when the government response is created" do
      let(:petition) { FactoryBot.create(:open_petition) }
      let(:government_response) { FactoryBot.build(:government_response, petition: petition) }
      let(:now) { Time.current }

      it "updates the government_response_at timestamp" do
        expect {
          government_response.save!
        }.to change {
          petition.reload.government_response_at
        }.from(nil).to(be_within(1.second).of(now))
      end
    end
  end
end
