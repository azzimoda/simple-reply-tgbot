# frozen_string_literal: true

require_relative 'custom_control'
require_relative 'general'
require_relative 'text'

# App
class App
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
end
