# frozen_string_literal: true

require_relative '../logger'

# Telegram chat
class Chat < ActiveRecord::Base
  validates :tg_chat_id, presence: true, uniqueness: true

  def private?
    tg_chat_id.positive?
  end
end
