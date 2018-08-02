class Admin::GovernmentResponseController < Admin::AdminController
  before_action :fetch_petition
  before_action :fetch_government_response

  rescue_from ActiveRecord::RecordNotUnique do
    @government_response = @petition.government_response(true) and update
  end

  def show
    render 'admin/petitions/show'
  end

  def update
    if @government_response.update(government_response_params)
      if send_email_to_petitioners?
        EmailThresholdResponseJob.run_later_tonight(petition: @petition)
        message = :email_sent_overnight
      else
        message = :government_response_updated
      end

      redirect_to [:admin, @petition], notice: message
    else
      render 'admin/petitions/show'
    end
  end

  private

  def fetch_petition
    @petition = Petition.moderated.find(params[:petition_id])
  end

  def fetch_government_response
    @government_response = @petition.government_response || @petition.build_government_response
  end

  def government_response_params
    params.require(:government_response).permit(:summary, :details)
  end

  def send_email_to_petitioners?
    params.key?(:save_and_email)
  end
end
