# frozen_string_literal: true

# Quickly deletes a set of responses.
class ResponseDestroyer < ApplicationDestroyer
  def destroy!
    ActiveRecord::Base.transaction do
      # The destroyer is responsible for checking destroy permissions so we do so here.
      ids = scope.accessible_by(ability, :destroy).pluck(:id)
      unless ids.empty?
        Media::Object.joins(:answer).where(answers: {response_id: ids}).delete_all
        Choice.joins(:answer).where(answers: {response_id: ids}).delete_all
        Answer.where(response_id: ids).delete_all
        counts[:destroyed] = Response.where(id: ids).delete_all
      end
    end
    counts
  end
end
