module DayTimelinesScoped
  extend ActiveSupport::Concern

  included do
    include FilterScoped

    before_action :clear_collections_filter, if: -> { params[:clear_filter] }
    before_action :restore_collections_filter_from_cookie
    before_action :set_day_timeline

    after_action :save_collection_filter
  end

  private
    def clear_collections_filter
      cookies.delete(:collection_filter)
    end

    def restore_collections_filter_from_cookie
      if cookies[:collection_filter].present?
        @filter.collection_ids = cookies[:collection_filter].split(",")
      end
    end

    def set_day_timeline
      @day_timeline = Current.user.timeline_for(day, filter: @filter)
    end

    def day
      if params[:day].present?
        Time.zone.parse(params[:day])
      else
        Time.current
      end
    rescue ArgumentError
      head :not_found
    end

    def save_collection_filter
      if params[:collection_ids].present?
        cookies[:collection_filter] = params[:collection_ids].join(",")
      end
    end
end
