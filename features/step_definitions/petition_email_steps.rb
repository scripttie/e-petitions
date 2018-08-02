When(/^I fill in the email details$/) do
  fill_in "Subject", :with => "Petition email subject"
  fill_in "Body", :with => "Petition email body"
end

Given(/^it has an existing petition email "(.*?)"$/) do |subject|
  @email = FactoryBot.create(:petition_email, petition: @petition, subject: subject)
end

Then(/^the petition should not have any emails$/) do
  @petition.reload
  expect(@petition.emails).to be_empty
end

Then(/^the petition should have the email details I provided$/) do
  @petition.reload
  @email = @petition.emails.last
  expect(@email.subject).to eq("Petition email subject")
  expect(@email.body).to match(%r[Petition email body])
  expect(@email.sent_by).to eq("Admin User")
end

Then(/^the petition creator should have been emailed with the update$/) do
  @petition.reload
  steps %Q(
    Then "#{@petition.creator.email}" should receive an email
    When they open the email
    Then they should see "Petition email body" in the email body
    When they follow "#{petition_url(@petition)}" in the email
    Then I should be on the petition page for "#{@petition.action}"
  )
end

Then(/^the petition creator should not have been emailed with the update$/) do
  @petition.reload
  steps %Q(
    Then "#{@petition.creator.email}" should receive no emails
  )
end

Then(/^all the signatories of the petition should have been emailed with the update$/) do
  @petition.reload
  @petition.signatures.validated.subscribed.where.not(id: @petition.creator.id).each do |signatory|
    steps %Q(
      Then "#{signatory.email}" should receive an email
      When they open the email
      Then they should see "Petition email body" in the email body
      When they follow "#{petition_url(@petition)}" in the email
      Then I should be on the petition page for "#{@petition.action}"
    )
  end
end

Then(/^all the signatories of the petition should not have been emailed with the update$/) do
  @petition.reload
  @petition.signatures.validated.subscribed.where.not(id: @petition.creator.id).each do |signatory|
    steps %Q(
      Then "#{signatory.email}" should receive no emails
    )
  end
end

Then(/^the feedback email address should have been emailed a copy$/) do
  signatory = FeedbackSignature.new(@petition)
  steps %Q(
    Then "#{signatory.email}" should receive an email
    When they open the email
    Then they should see "Petition email body" in the email body
    When they follow "#{petition_url(@petition)}" in the email
    Then I should be on the petition page for "#{@petition.action}"
  )
end

Then(/^the feedback email address should not have been emailed a copy$/) do
  signatory = FeedbackSignature.new(@petition)
  steps %Q(
    Then "#{signatory.email}" should receive no emails
  )
end
