# frozen_string_literal: true

require 'json'

require_relative '../helpers/api'

# App
class App
  HELP_MESSAGE_TEXT = <<~TEXT
    Available commands:

    /add - Add a new command
    /remove - Remove a command
    /commands - Show commands of all admins of the chat
    /mycommands - Show my commands

    /cancel - Cancel current action

    /help - Show this message
    /start - Start the bot
  TEXT

  private

  def handle_command_start(message)
    log.debug 'handle_command_start'

    bot.api.answer_message message, reply: true, text: 'Welcome! Use /help for command list'
  end

  def handle_command_help(message)
    log.debug 'handle_command_help'

    bot.api.answer_message message, reply: true, text: HELP_MESSAGE_TEXT
  end

  def handle_command_cancel(message)
    log.debug 'handle_command_cancel'

    user = User.find_by tg_user_id: message.from.id
    user.update state: nil, key_to_add: nil

    bot.api.answer_message message, reply: true, text: 'Cancelled'
  end
end
