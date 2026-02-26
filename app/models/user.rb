# frozen_string_literal: true

require_relative '../logger'

# Telegram user
class User < ActiveRecord::Base
  has_many :commands
  validates :tg_user_id, presence: true, uniqueness: true

  def add_command(key, response)
    commands.create key: key, response: response
    log.debug "Added command #{key} for chat #{id}"
  end
end
