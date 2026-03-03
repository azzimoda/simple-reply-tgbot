# frozen_string_literal: true

require 'json'

require_relative '../helpers/api'
require_relative '../utils'

# App
class App
  private

  def handle_custom_command(message)
    log.debug 'handle_custom_command'

    if (command = find_custom_command(message))
      log.debug "Matched command: #{command.inspect}"

      send_chat_action_typing message
      bot.api.set_message_reaction chat_id: message.chat.id, message_id: message.message_id,
                                   reaction: [{ type: 'emoji', emoji: '❤' }]

      case command.response_kind

      when 'text'    then send_response_text    message, command
      when 'sticker' then send_response_sticker message, command
      when 'photo'   then send_response_photo   message, command

      else log.warn "Unknown response kind: #{command.response_kind}"
      end
    end
  end

  def find_custom_command(message)
    chat_commands(message.chat.id)&.find { it.key == message.text.downcase }
  end

  def send_response_text(message, command)
    log.debug 'send_response_text'

    params =
      if command.response_button_link
        { reply_markup: { inline_keyboard: [[{
          text: 'Link', url: command.response_button_link
        }]] }.to_json }
      end
    bot.api.answer_message message, reply: true, text: command.response_data, **params
  end

  def send_response_sticker(message, command)
    log.debug 'send_response_sticker'

    bot.api.send_sticker(
      chat_id: message.chat.id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      sticker: command.response_data
    )
  end

  def send_response_photo(message, command)
    log.debug 'send_response_photo'

    bot.api.send_photo(
      chat_id: message.chat.id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      photo: command.response_data
    )
  end
end
