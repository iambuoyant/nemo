# frozen_string_literal: true

# == Schema Information
#
# Table name: skip_rules
#
#  id             :uuid             not null, primary key
#  destination    :string           not null
#  rank           :integer          not null
#  skip_if        :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  dest_item_id   :uuid
#  mission_id     :uuid
#  source_item_id :uuid             not null
#
# Indexes
#
#  index_skip_rules_on_dest_item_id    (dest_item_id)
#  index_skip_rules_on_source_item_id  (source_item_id)
#
# Foreign Keys
#
#  fk_rails_...  (dest_item_id => form_items.id)
#  fk_rails_...  (source_item_id => form_items.id)
#

# Models a rule directing the user to a given question if some conditions are true.
class SkipRule < ActiveRecord::Base
  include FormLogical

  belongs_to :dest_item, class_name: "FormItem", inverse_of: :incoming_skip_rules
  belongs_to :source_item, class_name: "FormItem"

  before_validation :normalize

  validate :require_dest_item

  replicable child_assocs: [:conditions],
             backward_assocs: [
               :source_item,
               # This is a second pass association because the
               # dest_item won't have been copied yet on the 1st pass.
               {name: :dest_item, second_pass: true}
             ]

  def all_fields_blank?
    destination.blank? && dest_item.blank? && conditions.all?(&:all_fields_blank?)
  end

  def condition_group
    @condition_group ||= Forms::ConditionGroup.new(
      true_if: skip_if,
      members: conditions,
      negate: true,
      name: "Skip for #{source_item.code}"
    )
  end

  # Duck type used for retrieving the main FormItem associated with this object, which is src_item.
  def base_item
    source_item
  end

  def left_qings
    conditions.map(&:left_qing)
  end

  private

  def normalize
    if conditions.reject(&:marked_for_destruction?).none?
      self.skip_if = "always"
    elsif skip_if == "always"
      self.skip_if = "all_met"
    end
  end

  def require_dest_item
    errors.add(:dest_item_id, :blank_unless_goto_end) if destination != "end" && dest_item.nil?
  end
end
