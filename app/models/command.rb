# frozen_string_literal: true

# Custom chat command
class Command < ActiveRecord::Base
  belongs_to :user
  validates :key, presence: true, uniqueness: { scope: :user }
end
