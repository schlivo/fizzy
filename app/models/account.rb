class Account < ApplicationRecord
  include Joinable

  has_many :buckets, dependent: :destroy
  has_many :bubbles, through: :buckets

  has_many :users, dependent: :destroy

  has_many :workflows, dependent: :destroy
  has_many :stages, through: :workflows, class_name: "Workflow::Stage"

  has_many :tags, dependent: :destroy
end
