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
    text =
      if user.commands.empty? then 'You have no commands. You can create one with command /add'
      else "Your commands: #{user.commands.map { it.key }.join(', ')}"
      end

    bot.api.answer_message message, reply: true, text: text
  end

  def handle_command_commands(message)
    commands = chat_commands message.chat.id
    text =
      if commands.empty? then 'No one of chat admins have added commands'
      else "Commands of this chat:\n\n#{format_chat_commands commands}"
      end

    bot.api.answer_message message, reply: true, text: text
  end

  def format_chat_commands(commands)
    commands.group_by { it.user }.map do |user, commands|
      username = bot.api.get_chat(chat_id: user.tg_user_id).then { |chat| chat&.username || chat&.first_name }
      "@#{username}: #{commands.map { it.key }.join(', ')}"
    end.join("\n\n")
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
      if (command = user.commands.find { it.key == Regexp.last_match(1).strip.downcase })
        return handle_command_remove_key message, command
      end

      bot.api.answer_message message, reply: true, text: 'No such command'
    end

    user.update state: STATE_REMOVE

    bot.api.answer_message message, text: 'Send me key of a command to remove or /cancel',
                                    reply_markup: remove_command_reply_markup(user)
  end

  def remove_command_reply_markup(user)
    { keyboard: user.commands.map { [it.key] },
      resize_keyboard: true,
      one_time_keyboard: true,
      selective: true }.to_json
  end

  def handle_command_remove_key(message, command)
    command.destroy
    bot.api.answer_message message, reply: true, text: "Command \"#{command.key}\" removed"
  end
end
