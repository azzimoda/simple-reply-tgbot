# frozen_string_literal: true

require 'json'

require_relative '../helpers/api'
require_relative '../helpers/callback_command'
require_relative '../utils'

require_relative 'custom_commands'

# App
class App
  private

  def handle_message_text(message)
    log.debug 'handle_message_text'

    return unless message.from

    user = User.find_by tg_user_id: message.from.id

    case [user&.state, user&.key_to_add]

    in [STATE_REMOVE,   _]   then send_chat_action_typing(message).then { handle_remove_key   message, user }
    in [STATE_ADD,      nil] then send_chat_action_typing(message).then { handle_add_key      message, user }
    in [STATE_ADD,      _]   then send_chat_action_typing(message).then { handle_add_response message, user }
    in [STATE_ADD_LINK, _]   then send_chat_action_typing(message).then { handle_add_link     message, user }

    else handle_custom_command message
    end
  end

  def handle_remove_key(message, user)
    log.debug 'handle_remove_key'

    unless message.text
      return bot.api.answer_message message, reply: true, text: 'No such command, try again or /cancel'
    end

    key = message.text.downcase
    if user.commands.none? { it.key == key }
      bot.api.answer_message message, reply: true, text: 'No such command, try again or /cancel'
    else
      user.update state: nil
      user.commands.find_by(key: key).destroy

      bot.api.answer_message message, reply: true, text: 'Command removed'
    end
  end

  def handle_add_key(message, user)
    log.debug 'handle_add_key'

    unless message.text
      return bot.api.answer_message message, reply: true, text: 'Key must be a text, try again or /cancel'
    end

    if Command.exists? user: user, key: message.text.downcase
      log.warn "Command already exists: #{message.text.downcase}"
      return bot.api.answer_message message, reply: true, text: 'Command already exists, try again or /cancel'
    end

    user.update key_to_add: message.text.downcase

    bot.api.answer_message message, reply: true, text: "Key: #{message.text}\nNow send me what to response or /cancel"
  end

  def handle_add_response(message, user)
    log.debug 'handle_add_response'

    command =
      case message
      when Telegram::Bot::Types::Message then handle_add_response_message message, user
      else return bot.api.answer_message message, reply: true, text: 'Unsupported message type, try again or /cancel'
      end

    unless command
      return bot.api.answer_message(
        message,
        reply: true,
        text: 'Failed to save command with this response, try again or /cancel'
      )
    end

    user.update state: nil, key_to_add: nil
    log.debug Command.find_by key: user.key_to_add, user: user

    params =
      if %w[text photo].include? command.response_kind
        { reply_markup: { inline_keyboard: [[{
          text: 'Add link',
          callback_data: CallbackCommand.new('add_link', command.key).to_s
        }]] }.to_json }
      end
    bot.api.answer_message message, reply: true, text: 'Command saved', **params
  end

  def handle_add_response_message(message, user)
    log.debug 'handle_add_response_message'

    if message.sticker then handle_add_response_sticker message, user
    elsif message.photo then handle_add_response_photo message, user
    elsif message.text then handle_add_response_text message, user
    end
  end

  def handle_add_response_text(message, user)
    log.debug 'handle_add_response_text'

    Command.new(
      user: user,
      key: user.key_to_add,
      response_kind: 'text',
      response_data: message.text
    ).tap(&:save)
  end

  def handle_add_response_sticker(message, user)
    log.debug 'handle_add_response_sticker'

    Command.new(
      user: user,
      key: user.key_to_add,
      response_kind: 'sticker',
      response_data: message.sticker.file_id
    ).tap(&:save)
  end

  def handle_add_response_photo(message, user)
    log.debug 'handle_add_response_photo'

    Command.new(
      user: user,
      key: user.key_to_add,
      response_kind: 'photo',
      response_data: message.photo.last[:file_id] # Highest resolution
    ).tap(&:save)
  end

  def handle_add_link(message, user)
    log.debug 'handle_add_link'

    command = Command.find_by user: user, key: user.key_to_add

    if command
      command.update response_button_link: message.text
      user.update state: STATE_DEFAULT, key_to_add: nil
      bot.api.answer_message message, reply: true, text: 'Link added successfully'
    else
      bot.api.answer_message message, reply: true, text: 'Failed to add link the command, try again or /cancel'
    end
  end
end
