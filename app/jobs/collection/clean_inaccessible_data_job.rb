class Collection::CleanInaccessibleDataJob < ApplicationJob
  def perform(user, collection)
    collection.clean_inaccessible_data_for(user)
  end
end
