require_dependency 'archived'

module Archived
  class GovernmentResponse < ActiveRecord::Base
    belongs_to :petition, touch: true

    validates :petition, presence: true
    validates :summary, presence: true, length: { maximum: 500 }
    validates :details, length: { maximum: 10000 }, allow_blank: true

    after_create do
      petition.touch(:government_response_at) unless petition.government_response_at?
    end
  end
end
