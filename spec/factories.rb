require 'factory_bot'

FactoryBot.define do
  factory :admin_user do
    sequence(:email) {|n| "admin#{n}@example.com" }
    password              "Letmein1!"
    password_confirmation "Letmein1!"
    sequence(:first_name) {|n| "AdminUser#{n}" }
    sequence(:last_name) {|n| "AdminUser#{n}" }
    force_password_reset  false
  end

  factory :sysadmin_user, :parent => :admin_user do
    role "sysadmin"
  end

  factory :moderator_user, :parent => :admin_user do
    role "moderator"
  end

  factory :archived_debate_outcome, class: "Archived::DebateOutcome" do
    association :petition, factory: :archived_petition
    debated_on { 1.year.ago.to_date }
    debated true

    trait :fully_specified do
      overview { 'Discussion of the 2014 Christmas Adjournment - has the house considered everything it needs to before it closes for the festive period?' }
      sequence(:transcript_url) { |n|
        "http://www.publications.parliament.uk/pa/cm#{debated_on.strftime('%Y%m')}/cmhansrd/cm#{debated_on.strftime('%y%m%d')}/debtext/#{debated_on.strftime('%y%m%d')}-0003.htm##{debated_on.strftime('%y%m%d')}49#{ '%06d' % n }"
      }
      video_url {
        "http://parliamentlive.tv/event/index/#{SecureRandom.uuid}"
      }
      sequence(:debate_pack_url) { |n|
        "http://researchbriefings.parliament.uk/ResearchBriefing/Summary/CDP-#{debated_on.strftime('%Y')}-#{ '%04d' % n }"
      }
    end
  end

  factory :archived_government_response, class: "Archived::GovernmentResponse" do
    association :petition, factory: :archived_petition
    details "Government Response Details"
    summary "Government Response Summary"
  end

  factory :archived_note, class: "Archived::Note" do
    association :petition, factory: :archived_petition
    details "Petition notes"
  end

  factory :archived_petition_email, class: "Archived::Petition::Email" do
    association :petition, factory: :archived_petition
    subject "Message Subject"
    body "Message body"
    sent_by "Admin User"
  end

  factory :archived_petition, class: "Archived::Petition" do
    sequence(:action) { |n| "Petition #{n}" }
    state "closed"
    background "Petition background"
    signature_count 0
    opened_at { 2.years.ago }
    closed_at { 1.year.ago }

    after(:build) do |petition, evaluator|
      petition.parliament ||= Parliament.archived.first || FactoryBot.create(:parliament, :archived)
    end

    trait :response do
      government_response_at { 1.week.ago }

      transient do
        response_summary { "Response Summary" }
        response_details { "Response Details" }
      end

      after(:build) do |petition, evaluator|
        petition.build_government_response do |r|
          r.summary = evaluator.response_summary
          r.details = evaluator.response_details
        end
      end
    end

    trait :scheduled_for_debate do
      scheduled_debate_date { 1.week.from_now }
      debate_state "scheduled"
    end

    trait :debated do
      debate_outcome_at { 1.week.ago }
      debate_state "debated"

      transient do
        debated_on { 1.week.ago.to_date }
        overview { nil }
        transcript_url { nil }
        video_url { nil }
        debate_pack_url { nil }
        commons_image { nil }
      end

      after(:build) do |petition, evaluator|
        petition.build_debate_outcome do |o|
          o.debated = true
          o.debated_on = evaluator.debated_on if evaluator.debated_on.present?
          o.overview = evaluator.overview if evaluator.overview.present?
          o.transcript_url = evaluator.transcript_url if evaluator.transcript_url.present?
          o.video_url = evaluator.video_url if evaluator.video_url.present?
          o.debate_pack_url = evaluator.debate_pack_url if evaluator.debate_pack_url.present?
          o.commons_image = evaluator.commons_image if evaluator.commons_image.present?
        end
      end
    end

    trait :not_debated do
      transient do
        overview { nil }
      end

      after(:build) do |petition, evaluator|
        petition.build_debate_outcome do |o|
          o.debated = false
          o.overview = evaluator.overview if evaluator.overview.present?
        end
      end
    end

    trait :stopped do
      state "stopped"
      signature_count 5
      stopped_at { 6.months.ago }
    end

    trait :closed do
      state "closed"
      signature_count 100
      closed_at { 6.months.ago }
    end

    trait :rejected do
      state "rejected"
      opened_at nil
      closed_at nil

      transient do
        rejection_code { "duplicate" }
        rejection_details { nil }
      end

      after(:build) do |petition, evaluator|
        petition.build_rejection do |r|
          r.code = evaluator.rejection_code
          r.details = evaluator.rejection_details
        end
      end
    end

    trait :hidden do
      state "hidden"
      opened_at nil
      closed_at nil

      transient do
        rejection_code { "offensive" }
        rejection_details { nil }
      end

      after(:build) do |petition, evaluator|
        petition.build_rejection do |r|
          r.code = evaluator.rejection_code
          r.details = evaluator.rejection_details
        end
      end
    end
  end

  factory :archived_rejection, class: "Archived::Rejection" do
    association :petition, factory: :archived_petition
    code "duplicate"
  end

  factory :archived_signature, class: "Archived::Signature" do
    association :petition, factory: :archived_petition

    sequence(:name)   { |n| "Jo Public #{n}" }
    sequence(:email)  { |n| "jo#{n}@public.com" }
    postcode            "SW1A 1AA"
    location_code       "GB"
    state               Archived::Signature::VALIDATED_STATE
    unsubscribe_token { Authlogic::Random.friendly_token }

    trait :pending do
      state Archived::Signature::PENDING_STATE
    end

    trait :validated do
      state Archived::Signature::VALIDATED_STATE
    end
  end

  factory :petition do
    transient do
      admin_notes { nil }
      creator_name { nil }
      creator_attributes { {} }
      sponsors_signed nil
      sponsor_count { Site.minimum_number_of_sponsors }
    end

    sequence(:action) {|n| "Petition #{n}" }
    background "Petition background"
    creator { |cs| cs.association(:signature, creator_attributes.merge(creator: true, state: Signature::VALIDATED_STATE, validated_at: Time.current)) }

    after(:build) do |petition, evaluator|
      if petition.signature_count.zero?
        petition.signature_count += 1 if petition.creator.validated?
      end

      if evaluator.admin_notes
        petition.build_note details: evaluator.admin_notes
      end

      if evaluator.creator_name
        petition.creator.name = evaluator.creator_name
      end
    end

    after(:create) do |petition, evaluator|
      unless evaluator.sponsors_signed.nil?
        evaluator.sponsor_count.times do
          if evaluator.sponsors_signed
            FactoryBot.create(:sponsor, :validated, petition: petition)
          else
            FactoryBot.create(:sponsor, :pending, petition: petition)
          end
        end

        petition.update_signature_count!
      end
    end

    trait :with_additional_details do
      additional_details "Petition additional details"
    end

    trait :scheduled_for_debate do
      scheduled_debate_date { 10.days.from_now }
    end

    trait :email_requested do
      transient do
        email_requested_for_government_response_at { nil }
        email_requested_for_debate_scheduled_at { nil }
        email_requested_for_debate_outcome_at { nil }
        email_requested_for_petition_email_at { nil }
      end

      after(:build) do |petition, evaluator|
        petition.build_email_requested_receipt do |r|
          r.government_response = evaluator.email_requested_for_government_response_at
          r.debate_scheduled = evaluator.email_requested_for_debate_scheduled_at
          r.debate_outcome = evaluator.email_requested_for_debate_outcome_at
          r.petition_email = evaluator.email_requested_for_petition_email_at
        end
      end
    end

    trait :tagged do
      transient do
        tag_name { nil }
      end

      after(:build) do |petition, evaluator|
        if evaluator.tag_name
          tag = create(:tag, name: evaluator.tag_name)
        else
          tag = create(:tag)
        end

        petition.tags = [tag.id]
      end
    end
  end

  factory :pending_petition, :parent => :petition do
    state Petition::PENDING_STATE
    creator { |cs| cs.association(:signature, creator_attributes.merge(creator: true, state: Signature::PENDING_STATE)) }
  end

  factory :validated_petition, :parent => :petition do
    state  Petition::VALIDATED_STATE
  end

  factory :sponsored_petition, :parent => :petition do
    moderation_threshold_reached_at { Time.current }
    state  Petition::SPONSORED_STATE

    trait :overdue do
      moderation_threshold_reached_at { Site.moderation_overdue_in_days.ago - 5.minutes }
    end

    trait :nearly_overdue do
      moderation_threshold_reached_at { Site.moderation_overdue_in_days.ago + 5.minutes }
    end

    trait :recent do
      moderation_threshold_reached_at { Time.current }
    end
  end

  factory :flagged_petition, :parent => :petition do
    state  Petition::FLAGGED_STATE
  end

  factory :open_petition, :parent => :sponsored_petition do
    state  Petition::OPEN_STATE
    open_at { Time.current }
  end

  factory :closed_petition, :parent => :petition do
    state      Petition::CLOSED_STATE
    open_at    { 10.days.ago }
    closed_at  { 1.day.ago }
  end

  factory :stopped_petition, :parent => :petition do
    state  Petition::STOPPED_STATE
    stopped_at { 1.day.ago }
  end

  factory :rejected_petition, :parent => :petition do
    state Petition::REJECTED_STATE

    transient do
      rejection_code { "duplicate" }
      rejection_details { nil }
    end

    after(:create) do |petition, evaluator|
      petition.create_rejection! do |r|
        r.code = evaluator.rejection_code
        r.details = evaluator.rejection_details
      end
    end
  end

  factory :hidden_petition, :parent => :petition do
    state Petition::HIDDEN_STATE
  end

  factory :awaiting_petition, :parent => :open_petition do
    response_threshold_reached_at { 1.week.ago }
  end

  factory :responded_petition, :parent => :awaiting_petition do
    government_response_at { 1.week.ago }

    transient do
      response_summary { "Response Summary" }
      response_details { "Response Details" }
    end

    after(:create) do |petition, evaluator|
      petition.create_government_response! do |r|
        r.summary = evaluator.response_summary
        r.details = evaluator.response_details
      end
    end
  end

  factory :awaiting_debate_petition, :parent => :open_petition do
    debate_threshold_reached_at { 1.week.ago }
    debate_state 'awaiting'
  end

  factory :scheduled_debate_petition, :parent => :open_petition do
    debate_threshold_reached_at { 1.week.ago }
    scheduled_debate_date { 1.week.from_now }
    debate_state 'scheduled'
  end

  factory :debated_petition, :parent => :open_petition do
    transient do
      debated_on { 1.day.ago }
      overview { nil }
      transcript_url { nil }
      video_url { nil }
      debate_pack_url { nil }
      commons_image { nil }
    end

    debate_state 'debated'

    after(:build) do |petition, evaluator|
      debate_outcome_attributes = { petition: petition }

      debate_outcome_attributes[:debated_on] = evaluator.debated_on if evaluator.debated_on.present?
      debate_outcome_attributes[:overview] = evaluator.overview if evaluator.overview.present?
      debate_outcome_attributes[:transcript_url] = evaluator.transcript_url if evaluator.transcript_url.present?
      debate_outcome_attributes[:video_url] = evaluator.video_url if evaluator.video_url.present?
      debate_outcome_attributes[:debate_pack_url] = evaluator.debate_pack_url if evaluator.debate_pack_url.present?
      debate_outcome_attributes[:commons_image] = evaluator.commons_image if evaluator.commons_image.present?

      petition.create_debate_outcome(debate_outcome_attributes)
    end
  end

  factory :not_debated_petition, :parent => :open_petition do
    after(:create) do |petition, evaluator|
      petition.create_debate_outcome(debated: false)
    end
  end

  factory :signature do
    sequence(:name)  {|n| "Jo Public #{n}" }
    sequence(:email) {|n| "jo#{n}@public.com" }
    postcode              "SW1A 1AA"
    location_code         "GB"
    uk_citizenship        "1"
    notify_by_email       "1"
    state                 Signature::VALIDATED_STATE

    after(:create) do |signature, evaluator|
      if signature.petition && signature.validated?
        signature.petition.increment!(:signature_count)
        signature.increment!(:number)
      end
    end
  end

  factory :pending_signature, :parent => :signature do
    state      Signature::PENDING_STATE
  end

  factory :fraudulent_signature, :parent => :signature do
    state      Signature::FRAUDULENT_STATE
  end

  factory :validated_signature, :parent => :signature do
    state                         Signature::VALIDATED_STATE
    validated_at                  { Time.current }
    seen_signed_confirmation_page true

    trait :just_signed do
      seen_signed_confirmation_page false
    end
  end

  factory :invalidated_signature, :parent => :validated_signature do
    state                         Signature::INVALIDATED_STATE
    invalidated_at                { Time.current }
  end

  sequence(:sponsor_email) { |n| "sponsor#{n}@example.com" }

  factory :sponsor, parent: :pending_signature do
    sponsor true

    trait :pending do
      state "pending"
    end

    trait :validated do
      state "validated"
    end

    trait :just_signed do
      seen_signed_confirmation_page false
    end
  end

  sequence(:constituency_id) { |n| (1234 + n).to_s }
  sequence(:mp_id) { |n| (4321 + n).to_s }
  sequence(:ons_code) { |n| '%08d' % n }

  factory :constituency do
    trait(:england) do
      ons_code{ "E#{generate(:ons_code)}" }
    end

    trait(:scotland) do
      ons_code{ "S#{generate(:ons_code)}" }
    end

    trait(:wales) do
      ons_code{ "W#{generate(:ons_code)}" }
    end

    trait(:northern_ireland) do
      ons_code{ "N#{generate(:ons_code)}" }
    end

    trait(:coventry_north_east) do
      name "Coventry North East"
      slug "coventry-north-east"
      external_id "3427"
      ons_code "E14000649"
      mp_id "4378"
      mp_name "Colleen Fletcher MP"
      mp_date "2015-05-07"
      example_postcode "CV21PH"
    end

    trait(:bethnal_green_and_bow) do
      name "Bethnal Green and Bow"
      slug "bethnal-green-and-bow"
      external_id "3320"
      ons_code "E14000555"
      mp_id "4138"
      mp_name "Rushanara Ali MP"
      mp_date "2015-05-07"
      example_postcode "E27AX"
    end

    trait(:romford) do
      name "Romford"
      slug "romford"
      external_id "3703"
      ons_code "E14000900"
      mp_id "1447"
      mp_name "Andrew Rosindell"
      mp_date "2015-05-07"
      example_postcode "RM53FZ"
    end

    trait(:sheffield_brightside_and_hillsborough) do
      name "Sheffield, Brightside and Hillsborough"
      slug "sheffield-brightside-and-hillsborough"
      external_id "3724"
      ons_code "E14000921"
      mp_id "4571"
      mp_name "Gill Furniss"
      mp_date "2016-05-05"
      example_postcode "S61AR"
    end

    trait(:london_and_westminster) do
      name "Cities of London and Westminster"
      slug "cities-of-london-and-westminster"
      external_id "3415"
      ons_code "E14000639"
      mp_id "1405"
      mp_name "Rt Hon Mark Field MP"
      mp_date "2017-06-08"
      example_postcode "SW1A1AA"
    end

    england

    name { Faker::Address.county }
    external_id { generate(:constituency_id) }
    mp_name { "#{Faker::Name.name} MP" }
    mp_id { generate(:mp_id) }
    example_postcode { Faker::Address.postcode }
  end

  factory :constituency_petition_journal do
    constituency_id "3415"
    association :petition
  end

  factory :country_petition_journal do
    location_code "GB"
    association :petition
  end

  factory :debate_outcome do
    association :petition, factory: :open_petition
    debated_on { 1.month.from_now.to_date }
    debated true

    trait :fully_specified do
      overview { 'Discussion of the 2014 Christmas Adjournment - has the house considered everything it needs to before it closes for the festive period?' }
      sequence(:transcript_url) { |n|
        "http://www.publications.parliament.uk/pa/cm#{debated_on.strftime('%Y%m')}/cmhansrd/cm#{debated_on.strftime('%y%m%d')}/debtext/#{debated_on.strftime('%y%m%d')}-0003.htm##{debated_on.strftime('%y%m%d')}49#{ '%06d' % n }"
      }
      video_url {
        "http://parliamentlive.tv/event/index/#{SecureRandom.uuid}"
      }
      sequence(:debate_pack_url) { |n|
        "http://researchbriefings.parliament.uk/ResearchBriefing/Summary/CDP-#{debated_on.strftime('%Y')}-#{ '%04d' % n }"
      }
    end
  end

  factory :government_response do
    association :petition, factory: :awaiting_petition
    details "Government Response Details"
    summary "Government Response Summary"
  end

  factory :note do
    association :petition, factory: :petition
    details "Petition notes"
  end

  factory :petition_email, class: "Petition::Email" do
    association :petition, factory: :petition
    subject "Message Subject"
    body "Message body"
    sent_by "Admin User"
  end

  factory :rejection do
    association :petition, factory: :validated_petition
    code "duplicate"
  end

  factory :email_requested_receipt do
    association :petition, factory: :open_petition
  end

  factory :location do
    code { Faker::Address.country_code }
    name { Faker::Address.country }

    trait :pending do
      start_date { 3.months.from_now }
    end

    trait :expired do
      end_date { 2.years.ago }
    end
  end

  factory :feedback do
    comment "This thing is wrong"
    petition_link_or_title "Do stuff"
    email "foo@example.com"
    user_agent "Mozilla/5.0"
  end

  factory :invalidation do
    summary "Invalidation summary"
    details "Reasons for invalidation"

    trait :cancelled do
      cancelled_at { Time.current }
    end

    trait :completed do
      completed_at { Time.current }
    end

    trait :started do
      started_at { Time.current }
    end
  end

  factory :parliament do
    government "Conservative"
    opening_at { "2015-05-18T00:00:00".in_time_zone }

    trait :dissolving do
      dissolution_heading "Parliament is dissolving"
      dissolution_message "This means all petitions will close in 2 weeks"
      dissolution_at { 2.weeks.from_now }
    end

    trait :dissolved do
      dissolution_heading "Parliament is dissolving"
      dissolution_message "This means all petitions will close in 2 weeks"
      dissolved_heading "Parliament is dissolved"
      dissolved_message "All petitions are now closed"
      dissolution_at { 2.weeks.ago }
    end

    trait :coalition do
      government "Conservative - Liberal Democrat coalition"
      opening_at { "2010-05-18T00:00:00".in_time_zone }
      dissolution_heading "Parliament is dissolving"
      dissolution_message "This means all petitions will close in 2 weeks"
      dissolved_heading "Parliament is dissolved"
      dissolved_message "All petitions are now closed"
      dissolution_at { "2015-03-30T00:01:00".in_time_zone }
      archived_at { "2015-07-20T00:00:00" }
    end

    trait :conservatives do
      government "Conservative"
      opening_at { "2015-05-18T00:00:00".in_time_zone }
      dissolution_heading "Parliament is dissolving"
      dissolution_message "This means all petitions will close in 2 weeks"
      dissolved_heading "Parliament is dissolved"
      dissolved_message "All petitions are now closed"
      dissolution_at { "2017-05-13T00:01:00" }
      archived_at { "2017-06-08T00:00:00" }
    end

    trait :new_government do
      government "TBC"
      opening_at { "2017-06-19T00:00:00".in_time_zone }
    end

    trait :archived do
      archived_at { 1.month.ago }
    end
  end

  factory :tag do
    sequence(:name) { |n| "Tag #{n}" }
  end
end
