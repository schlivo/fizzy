class Cards::StagingsController < ApplicationController
  include CardScoped

  def update
    @card.change_stage_to @collection.workflow.stages.find(params[:stage_id])
    render_card_replacement
  end
end
