# frozen_string_literal: true

require 'json'

require_relative '../helpers/api'

# App
class App
  STATE_DEFAULT = nil
  STATE_ADD = 'add'
  STATE_ADD_LINK = 'add_link'
  STATE_REMOVE = 'remove'

  private

  def handle_command_mycommands(message)
    log.debug 'handle_command_mycommands'
    user = User.find_by tg_user_id: message.from.id
    if user.commands.empty?
      bot.api.answer_message message, reply: true, text: 'You have no commands. You can create one with command /add'
    else
      commands = user.commands.map { it.key }.join(', ')
      bot.api.answer_message message, reply: true, text: "Your commands: #{commands}"
    end
  end

  def handle_command_commands(message)
    commands = chat_commands message.chat.id
    if commands.empty?
      bot.api.answer_message message, reply: true, text: 'No one of chat admins have added commands'
    else
      commands = commands.map { it.key }.join(', ') # TODO: Group commands by users
      bot.api.answer_message message, reply: true, text: "Commands of this chat: #{commands}"
    end
  end

  def handle_command_add(message)
    log.debug 'handle_command_add'

    user = User.find_by tg_user_id: message.from.id
    user.update state: STATE_ADD, key_to_add: nil

    bot.api.answer_message message, reply: true, text: 'Send me a key or /cancel'
  end

  def handle_command_remove(message)
    user = User.find_by tg_user_id: message.from.id

    return bot.api.answer_message message, reply: true, text: 'You have no commands' if user.commands.empty?

    if message.text =~ %r{/remove\s+(.+)$}
      key = Regexp.last_match(1).strip.downcase
      if (command = user.commands.find { it.key == key })
        command.destroy
        bot.api.answer_message message, reply: true, text: "Command \"#{command.key}\" removed"
      else
        bot.api.answer_message message, reply: true, text: 'No such command'
      end
    end

    user.update state: STATE_REMOVE

    markup = {
      keyboard: user.commands.map { [it.key] },
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true
    }.to_json
    bot.api.answer_message message, text: 'Send me a key of a command to remove or /cancel', reply_markup: markup
  end
end
