class Cards::DropsController < ApplicationController
  before_action :set_filter, :set_card, :set_drop_target

  def create
    case @drop_target
    when :considering
      @card.reconsider
    when :doing
      @card.engage
    end

    render_column_replacement
  end

  private
    VALID_DROP_TARGETS = %w[ considering doing ]

    def set_filter
      @filter = Current.user.filters.from_params params.reverse_merge(**FilterScoped::DEFAULT_PARAMS).permit(*Filter::PERMITTED_PARAMS)
    end

    def set_card
      @card = Current.user.accessible_cards.find(params[:dropped_item_id])
    end

    def set_drop_target
      if params[:drop_target].in?(VALID_DROP_TARGETS)
        @drop_target = params[:drop_target].to_sym
      else
        head :bad_request
      end
    end

    def render_column_replacement
      page_and_filter = page_and_filter_for @filter.with(engagement_status: @drop_target.to_s), per_page: CardsController::PAGE_SIZE
      render turbo_stream: turbo_stream.replace("#{@drop_target}-cards", method: :morph, partial: "cards/index/engagement/#{@drop_target}", locals: page_and_filter.to_h)
    end

    def page_and_filter_for(filter, per_page: nil)
      cards = block_given? ? yield(filter.cards) : filter.cards

      OpenStruct.new \
        page: GearedPagination::Recordset.new(cards, per_page:).page(1),
        filter: filter
    end
end
