class SearchesController < ApplicationController
  include Turbo::DriveHelper

  def show
    # Try to find by number first (most common case), then by UUID
    card = if params[:q] =~ /^\d+$/
      Current.user.accessible_cards.find_by(number: params[:q].to_i)
    else
      Current.user.accessible_cards.find_by_id(params[:q])
    end
    
    if card
      @card = card
    else
      set_page_and_extract_portion_from Current.user.search(params[:q])
      @recent_search_queries = Current.user.search_queries.order(updated_at: :desc).limit(10)
    end
  end
end
