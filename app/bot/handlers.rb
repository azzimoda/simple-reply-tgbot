# frozen_string_literal: true

require 'pp'

require_relative 'handlers/commands'
require_relative 'handlers/text'

# App
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

    bot.api.answer_message(
      message,
      reply: true,
      text: "No one of admins of this chat has registered. Please, start the bot: @#{bot.api.get_me.username}"
    )
  end
end
