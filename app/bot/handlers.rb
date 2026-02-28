# frozen_string_literal: true

require 'pp'

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

  def handle_update(update)
    case update
    when Telegram::Bot::Types::Message then handle_message update
    else log.warn "Unhandled update type: #{update.class}"
    end
  rescue Telegram::Bot::Exceptions::ResponseError => e
    log.error "Telegram API error: #{e.message}"
  rescue StandardError => e
    log.error "handle_update: Unexpected error: #{e.message}"
    log.error "Backtrace:\n#{e.backtrace.join("\n")}"
  end

  def handle_message(message)
    # Skip too old messages: >10 minutes
    return log.debug "Old message skipped: #{Time.at(message.date)}" if Time.at(message.date) < Time.now - 600

    log.debug "Received update:\n#{message.to_h.pretty_inspect}"

    if message.chat.type == 'private'
      handle_private_message message
    else
      handle_group_message message
    end
  end

  def handle_private_message(message)
    log.debug 'handle_private_message'
    return log.warn "Update doesn't have key `from`" unless message.from

    unless User.find_by tg_user_id: message.from.id
      log.debug "New user: #{message.from.id} (@#{message.from.username}, #{message.from.first_name})"
    end
    _user = User.find_or_create_by tg_user_id: message.from.id

    if message.text&.start_with?('/')
      handle_command message
    else
      handle_message_text message
    end
  end

  def handle_command(message)
    log.debug 'handle_command'
    case message.text =~ command_re ? Regexp.last_match(1) : message.text
    when %r{^/start$}i then handle_command_start message
    when %r{^/help$}i then handle_command_help message
    when %r{^/cancel|^cancel$}i then handle_command_cancel message
    when %r{^/commands$}i then handle_command_commands message
    when %r{^/mycommands$}i then handle_command_mycommands message
    when %r{^/add}i then handle_command_add message
    when %r{^/remove}i then handle_command_remove message
    else handle_message_text message
    end
  end

  def handle_command_start(message)
    log.debug 'handle_command_start'

    bot.api.send_message(
      chat_id: message.chat.id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      text: 'Welcome! Use /help for command list'
    )
  end

  def handle_command_help(message)
    log.debug 'handle_command_help'

    bot.api.send_message(
      chat_id: message.chat.id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      text: HELP_MESSAGE_TEXT
    )
  end

  def handle_command_cancel(message)
    log.debug 'handle_command_cancel'
    user = User.find_by tg_user_id: message.from.id
    user.update state: nil, key_to_add: nil
    bot.api.send_message(
      chat_id: message.chat.id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      text: 'Cancelled'
    )
  end

  def handle_command_mycommands(message)
    log.debug 'handle_command_mycommands'
    user = User.find_by tg_user_id: message.from.id
    if user.commands.empty?
      bot.api.send_message(
        chat_id: message.chat.id, message_thread_id: message.message_thread_id,
        reply_parameters: { message_id: message.message_id }.to_json,
        text: 'You have no commands. You can create one with command /add'
      )
    else
      commands = user.commands.map { it.key }.join(', ')
      bot.api.send_message(
        chat_id: message.chat.id, message_thread_id: message.message_thread_id,
        reply_parameters: { message_id: message.message_id }.to_json,
        text: "Your commands: #{commands}"
      )
    end
  end

  def handle_command_commands(message)
    commands = chat_commands message.chat.id
    if commands.empty?
      bot.api.send_message(
        chat_id: message.chat.id, message_thread_id: message.message_thread_id,
        reply_parameters: { message_id: message.message_id }.to_json,
        text: 'No one of chat admins have added commands'
      )
    else
      commands = commands.map { it.key }.join(', ') # TODO: Group commands by users
      bot.api.send_message(
        chat_id: message.chat.id, message_thread_id: message.message_thread_id,
        reply_parameters: { message_id: message.message_id }.to_json,
        text: "Commands of this chat: #{commands}"
      )
    end
  end

  def handle_command_add(message)
    log.debug 'handle_command_add'

    user = User.find_by tg_user_id: message.from.id
    user.update state: 'add', key_to_add: nil

    bot.api.send_message(
      chat_id: message.chat.id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      text: 'Send me a key or /cancel'
    )
  end

  def handle_command_remove(message)
    user = User.find_by tg_user_id: message.from.id
    chat_id = message.chat.id

    if user.commands.empty?
      bot.api.send_message(
        chat_id: chat_id, message_thread_id: message.message_thread_id,
        reply_parameters: { message_id: message.message_id }.to_json,
        text: 'You have no commands'
      )
      return
    end

    if message.text =~ %r{/remove\s+(.+)$}
      key = Regexp.last_match(1).strip.downcase
      if (command = user.commands.find { it.key == key })
        command.destroy
        return bot.api.send_message(
          chat_id: chat_id, message_thread_id: message.message_thread_id,
          reply_parameters: { message_id: message.message_id }.to_json,
          text: "Command \"#{command.key}\" removed"
        )
      else
        bot.api.send_message(
          chat_id: chat_id, message_thread_id: message.message_thread_id,
          reply_parameters: { message_id: message.message_id }.to_json,
          text: 'No such command'
        )
      end
    end

    user.state = 'remove'
    user.save

    markup = {
      keyboard: user.commands.map { [it.key] },
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true
    }.to_json
    bot.api.send_message(
      chat_id: chat_id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      text: 'Send me a key of a command to remove or /cancel',
      reply_markup: markup
    )
  end

  def handle_message_text(message)
    log.debug 'handle_message_text'

    return unless message.from && message.text

    user = User.find_by tg_user_id: message.from.id

    log.debug "User state: #{user.pretty_inspect}"
    case [user&.state, user&.key_to_add]
    in ['remove', _] then handle_remove_key message, user
    in ['add', nil] then handle_add_key message, user
    in ['add', response] then handle_add_response message, user, response: response
    else handle_custom_command message
    end
  end

  def handle_remove_key(message, user)
    log.debug 'handle_remove_key'

    user.update state: nil

    key = message.text.downcase
    if user.commands.none? { it.key == key }
      bot.api.send_message(
        chat_id: message.chat.id, message_thread_id: message.message_thread_id,
        reply_parameters: { message_id: message.message_id }.to_json,
        text: 'Command not found'
      )
    else
      user.commands.find_by(key: key).destroy
      bot.api.send_message(
        chat_id: message.chat.id, message_thread_id: message.message_thread_id,
        reply_parameters: { message_id: message.message_id }.to_json,
        text: 'Command removed'
      )
    end
  end

  def handle_add_key(message, user)
    log.debug 'handle_add_key'

    user.update key_to_add: message.text.downcase

    bot.api.send_message(
      chat_id: message.chat.id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      text: "Key: #{message.text}\nNow send me what to response or /cancel"
    )
  end

  def handle_add_response(message, user, response:)
    log.debug "Handling response: #{response.inspect}..."

    Command.new(user: user, key: user.key_to_add, response: message.text).save
    user.update state: nil, key_to_add: nil
    log.debug Command.find_by key: user.key_to_add, user: user

    bot.api.send_message(
      chat_id: message.chat.id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      text: 'Command saved'
    )
  end

  def handle_custom_command(message)
    log.debug 'handle_custom_command'

    commands = chat_commands message.chat.id
    log.debug "Commands: #{commands.inspect}"

    commands&.find do |command|
      next unless command.key == message.text.downcase

      log.debug "Matched command: #{command.inspect}"
      bot.api.send_message(
        chat_id: message.chat.id, message_thread_id: message.message_thread_id,
        reply_parameters: { message_id: message.message_id }.to_json,
        text: command.response
      )
      return nil
    end
  end

  def handle_group_message(message)
    log.debug 'handle_group_message'

    return handle_unregistered_group_message message unless registered_admins? message.chat.id

    if User.find_by(tg_user_id: message.from.id) && message.text.start_with?('/')
      handle_command message
    else
      handle_message_text message
    end
  end

  def handle_unregistered_group_message(message)
    log.debug 'handle_unregistered_group_message'

    bot.api.send_message(
      chat_id: message.chat.id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      text: "No one of admins of this chat has registered. Please, start the bot: @#{bot.api.get_me.username}"
    )
  end
end
