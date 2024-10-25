module FiltersHelper
  def main_filter_text
    (Bucket::View::ORDERS[params[:order_by]] || Bucket::View::STATUSES[params[:status]] || Bubble.default_order_by).humanize
  end

  def tag_filter_text
    if @filter&.tags
      @filter.tags.map(&:hashtag).to_choice_sentence
    else
      "any tag"
    end
  end

  def assignee_filter_text
    if @filter&.assignees
      "assigned to #{@filter.assignees.pluck(:name).to_choice_sentence}"
    else
      "assigned to anyone"
    end
  end

  # `#bubble_filter_params` is memoized to avoid spam in logs about unpermitted params
  def bubble_filter_params
    @bubble_filter_params ||= params.permit :order_by, :status, assignee_ids: [], tag_ids: []
  end

  # `#view_filter_params` is memoized to avoid spam in logs about unpermitted params
  def view_filter_params
    @view_filter_params ||= bubble_filter_params.merge params.permit(:term, :view_id)
  end

  def unassigned_filter_activated?
    params[:status] == "unassigned"
  end

  def default_filters?
    bubble_filter_params.values.all?(&:blank?) || bubble_filter_params.to_h == Bucket::View.default_filters
  end

  def bubble_filter_form_tag(path, method:, id: nil)
    form_tag path, method: method, id: id do
      yield if block_given?

      if params[:order_by].present?
        concat hidden_field_tag(:order_by, params[:order_by])
      end

      if params[:status].present?
        concat hidden_field_tag(:status, params[:status])
      end

      Array(params[:assignee_ids]).each do |assignee_id|
        concat hidden_field_tag("assignee_ids[]", assignee_id, id: nil)
      end

      Array(params[:tag_ids]).each do |tag_id|
        concat hidden_field_tag("tag_ids[]", tag_id, id: nil)
      end
    end
  end
end
