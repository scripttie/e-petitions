module Archived
  class SignaturesController < ApplicationController
    before_action :retrieve_signature
    before_action :verify_unsubscribe_token
    before_action :do_not_cache

    def unsubscribe
      @signature.unsubscribe!(token_param)

      respond_to do |format|
        format.html
      end
    end

    private

    def signature_id
      @signature_id ||= Integer(params[:id])
    end

    def token_param
      @token_param ||= params[:token].to_s.encode('utf-8', invalid: :replace)
    end

    def verify_unsubscribe_token
      unless @signature.unsubscribe_token == token_param
        raise ActiveRecord::RecordNotFound, "Unable to find Signature with unsubscribe token: #{token_param.inspect}"
      end
    end

    def retrieve_signature
      @signature = Archived::Signature.find(params[:id])
      @petition = @signature.petition

      if @signature.invalidated? || @signature.fraudulent?
        raise ActiveRecord::RecordNotFound, "Unable to find Signature with id: #{signature_id}"
      end
    end
  end
end
