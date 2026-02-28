class App
  private

  def handle_update(update)
    case update
    when Telegram::Bot::Types::Message then handle_message update
    else log.warn "Unhandled update type: #{update.class}"
    end
  rescue Telegram::Bot::Exceptions::ResponseError => e
    log.error "Telegram API error: #{e.message}"
  rescue StandardError => e
    log.error "Unexpected error: #{e.message}"
  end

  def handle_message(message)
    # Skip too old messages: >10 minutes
    return log.debug "Old message skipped: #{Time.at(message.date)}" if Time.at(message.date) < Time.now - 600

    log.debug message.to_h.inspect

    log.debug "Received message in chat @#{message.chat.username} #{message.chat.id} from @#{message.from&.username}:" \
      " #{message.text}"
    if message.chat.type == 'private'
      handle_private_message message
    else
      handle_group_message message
    end
  end

  def handle_private_message(message)
    log.debug 'handle_private_message'
    _user = User.find_or_create_by tg_user_id: message.from.id
    if message.text&.start_with?('/') then handle_command message
    else handle_custom_command message
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
    else handle_custom_command message
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
      text: <<~TEXT
        Available commands:

        /start - Start the bot
        /help - Show this message
        /add - Add a new command
        /remove - Remove a command
        /commands - Show all commands in chat
        /mycommands - Show my commands
      TEXT
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
    user.state = 'add'
    user.save

    bot.api.send_message(
      chat_id: message.chat.id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      text: 'Send me the key'
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
      text: 'Which command do you want to remove?',
      reply_markup: markup
    )
  end

  def handle_custom_command(message)
    return unless message.from && message.text

    user = User.find_by tg_user_id: message.from.id

    log.debug "User state: #{user.inspect}"
    case [user&.state, user&.key_to_add]
    in ['remove', _]
      log.debug 'Handling remove key'
      user.state = nil
      user.save

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

    in ['add', nil]
      log.debug 'Handling key'
      user.key_to_add = message.text.downcase
      user.save

      bot.api.send_message(
        chat_id: message.chat.id, message_thread_id: message.message_thread_id,
        reply_parameters: { message_id: message.message_id }.to_json,
        text: "Key: #{message.text}\nNow send me what to response"
      )

    in ['add', response]
      log.debug "Handling response: #{response.inspect}..."
      command = Command.new user: user, key: user.key_to_add, response: message.text
      command.save

      user.state = nil
      user.key_to_add = nil
      user.save

      log.debug Command.find_by key: user.key_to_add, user: user

      bot.api.send_message(
        chat_id: message.chat.id, message_thread_id: message.message_thread_id,
        reply_parameters: { message_id: message.message_id }.to_json,
        text: 'Command saved'
      )

    else
      log.debug 'handle_custom_command'

      return unless admin? message.chat.id, message.from.id

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
  end

  def handle_unregistered_group_message(message)
    bot.api.send_message(
      chat_id: message.chat.id, message_thread_id: message.message_thread_id,
      reply_parameters: { message_id: message.message_id }.to_json,
      text: "No one of admins of this chat has registered. Please, start the bot: @#{bot.api.get_me.username}"
    )
  end

  def handle_group_message(message)
    return handle_unregistered_group_message message unless registered_admins? message.chat.id

    log.debug 'handle_group_message'

    if User.find_by(tg_user_id: message.from.id) && message.text.start_with?('/') then handle_command message
    else handle_custom_command message
    end
  end
end
