# frozen_string_literal: true

# Custom chat command
class Command < ActiveRecord::Base
  belongs_to :user
  belongs_to :response
  validates :key, presence: true, uniqueness: { scope: :user }

  def response_text?
    response_kind == 'text'
  end

  def response_sticker?
    response_kind == 'sticker'
  end

  def response_photo?
    response_kind == 'photo'
  end
end
