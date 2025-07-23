# frozen_string_literal: true

class AllCircle
  attr_reader :id, :name

  def initialize
    @id = 0
    @name = "All Circles"
  end

  def members
    User.all
  end

  def members_count
    @members_count ||= User.all.count
  end
end
