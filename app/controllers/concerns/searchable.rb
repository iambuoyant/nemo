# frozen_string_literal: true

# Methods pertaining to searching for objects in a controller action.
module Searchable
  extend ActiveSupport::Concern

  # If params[:search] is present, runs a search of `klass`,
  # passing `relation` as the relation to which to apply the search,
  # and the current_mission as the search scope.
  #
  # Returns the new relation if search succeeds,
  # otherwise sets flash, flash[:search_error] = true, and returns `relation` unchanged.
  def apply_search(searcher_class, relation)
    query = params[:search]
    return relation if query.blank?

    searcher_class.new(relation: relation, query: query, scope: {mission: current_mission}).apply
  rescue Search::ParseError => error
    flash.now[:error] = error.to_s
    flash.now[:search_error] = true
    relation
  end

  def init_filter_data
    @all_forms = Form.all.map { |item| {name: item.name, id: item.id} }.sort_by_key
  end
end
