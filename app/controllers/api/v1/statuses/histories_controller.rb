# frozen_string_literal: true

class Api::V1::Statuses::HistoriesController < Api::BaseController
  include Authorization

  before_action -> { doorkeeper_authorize! :read, :'read:statuses' }
  before_action :require_user!
  before_action :set_status, only: [:index]

  def index
    render json: @status.edits, each_serializer: REST::StatusEditSerializer
  end

  private

  def set_status
    @status = Status.find(params[:status_id])
    authorize @status, :show?
  rescue Mastodon::NotPermittedError
    not_found
  end
end
