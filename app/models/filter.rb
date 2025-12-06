class Filter < ApplicationRecord
  include Fields, Params, Resources, Summarized

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { creator.account }

  class << self
    def from_params(params)
      find_by_params(params) || build(params)
    end

    def remember(attrs)
      create!(attrs)
    rescue ActiveRecord::RecordNotUnique
      find_by_params(attrs).tap(&:touch)
    end
  end

  def cards
    @cards ||= begin
      result = creator.accessible_cards.preloaded.published
      result = result.indexed_by(indexed_by)
      result = result.sorted_by(sorted_by)
      result = result.where(id: card_ids) if card_ids.present?
      result = result.where.missing(:not_now) unless include_not_now_cards?
      result = result.open unless include_closed_cards?
      result = result.unassigned if assignment_status.unassigned?
      result = result.assigned_to(assignees.ids) if assignees.present?
      result = result.where(creator_id: creators.ids) if creators.present?
      result = result.where(board: boards.ids) if boards.present?
      result = result.tagged_with(tags.ids) if tags.present?
      result = result.where("cards.created_at": creation_window) if creation_window
      result = result.closed_at_window(closure_window) if closure_window
      result = result.closed_by(closers) if closers.present?
      
      # Separate numeric terms (card numbers) from text terms
      numeric_terms, text_terms = terms.partition { |term| term =~ /^\d+$/ }
      
      # If we have numeric terms, find cards by number and combine with text search
      if numeric_terms.any?
        card_ids_by_number = numeric_terms.map do |term|
          creator.accessible_cards.find_by(number: term.to_i)&.id
        end.compact
        
        if card_ids_by_number.any?
          # Start with cards found by number
          numeric_result = result.where(id: card_ids_by_number)
          
          # If we also have text terms, combine with text search results
          if text_terms.any?
            text_result = text_terms.reduce(result) do |result, term|
              result.mentioning(term, user: creator)
            end
            # Combine: cards matching number OR cards matching text terms
            result = result.where(id: numeric_result.select(:id)).or(
              result.where(id: text_result.select(:id))
            )
          else
            result = numeric_result
          end
        elsif text_terms.any?
          # No cards found by number, but we have text terms, so search by text
          result = text_terms.reduce(result) do |result, term|
            result.mentioning(term, user: creator)
          end
        else
          # No cards found by number and no text terms
          result = result.none
        end
      elsif text_terms.any?
        # Only text terms, use normal text search
        result = text_terms.reduce(result) do |result, term|
          result.mentioning(term, user: creator)
        end
      end

      result.distinct
    end
  end

  def empty?
    self.class.normalize_params(as_params).blank?
  end

  def single_board
    boards.first if boards.one?
  end

  def single_workflow
    boards.first.workflow if boards.pluck(:workflow_id).uniq.one?
  end

  def cacheable?
    boards.exists?
  end

  def cache_key
    ActiveSupport::Cache.expand_cache_key params_digest, "filter"
  end

  def only_closed?
    indexed_by.closed? || closure_window || closers.present?
  end

  private
    def include_closed_cards?
      only_closed? || card_ids.present?
    end

    def include_not_now_cards?
      indexed_by.not_now? || card_ids.present?
    end
end
