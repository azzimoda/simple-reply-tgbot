# frozen_string_literal: true

# App
class App
  def handle_message_text(message)
    log.debug 'handle_message_text'

    return unless message.from

    user = User.find_by tg_user_id: message.from.id

    log.debug "User state: #{user.pretty_inspect}"
    case [user&.state, user&.key_to_add]
    in [STATE_REMOVE, _] then handle_remove_key message, user
    in [STATE_ADD, nil] then handle_add_key message, user
    in [STATE_ADD, _] then handle_add_response message, user
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

    user.update key_to_add: message.text.downcase

    bot.api.answer_message message, reply: true, text: "Key: #{message.text}\nNow send me what to response or /cancel"
  end

  def handle_add_response(message, user)
    log.debug 'handle_add_response'

    response =
      case message
      when Telegram::Bot::Types::Message then handle_add_response_message message, user
      else return bot.api.answer_message message, reply: true, text: 'Unsupported message type, try again or /cancel'
      end

    unless response
      return bot.api.answer_message(
        message,
        reply: true,
        text: 'Failed to save command with this response, try again or /cancel'
      )
    end

    user.update state: nil, key_to_add: nil
    log.debug Command.find_by key: user.key_to_add, user: user

    bot.api.answer_message message, reply: true, text: 'Command saved'
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

  def handle_custom_command(message)
    log.debug 'handle_custom_command'

    commands = chat_commands message.chat.id
    log.debug "Commands: #{commands.inspect}"

    commands&.each do |command|
      next unless command.key == message.text.downcase

      log.debug "Matched command: #{command.inspect}"

      case command.response_kind
      when 'text' then send_response_text message, command
      when 'sticker' then send_response_sticker message, command
      when 'photo' then send_response_photo message, command
      else log.warn "Unknown response kind: #{command.response_kind}"
      end
      break
    end
  end

  def send_response_text(message, command)
    log.debug 'send_response_text'

    bot.api.answer_message message, reply: true, text: command.response_data
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
