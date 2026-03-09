# frozen_string_literal: true

require_relative '../utils'

require_relative 'custom_control'
require_relative 'general'
require_relative 'text'

# App
class App
  def handle_command(message)
    log.debug 'handle_command'

    handler =
      case message.text =~ command_re ? Regexp.last_match(1) : message.text

      when %r{^/start$}i      then :handle_command_start
      when %r{^/help$}i       then :handle_command_help
      when %r{^/?cancel$}i    then :handle_command_cancel
      when %r{^/commands$}i   then :handle_command_commands
      when %r{^/mycommands$}i then :handle_command_mycommands
      when %r{^/add}i         then :handle_command_add
      when %r{^/remove}i      then :handle_command_remove

      else return handle_message_text message
      end

    send_chat_action_typing message
    send handler, message
  end
end
