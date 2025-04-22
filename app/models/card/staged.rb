module Card::Staged
  extend ActiveSupport::Concern

  included do
    belongs_to :stage, class_name: "Workflow::Stage", optional: true

    before_create :assign_initial_stage

    scope :in_stage, ->(stage) { where stage: stage }
  end

  def workflow
    stage&.workflow
  end

  def change_stage_to(new_stage)
    transaction do
      update! stage: new_stage
      track_event :staged, stage_id: new_stage.id, stage_name: new_stage.name
    end
  end

  private
    def assign_initial_stage
      self.stage = collection.initial_workflow_stage
    end
end
