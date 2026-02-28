# frozen_string_literal: true

require 'pp'

require_relative '../database'

require_relative 'handlers/commands'
require_relative 'handlers/text'
require_relative 'helpers/api'
require_relative 'helpers/callback_command'

# App
class App
  private

  def handle_update(update)
    case update
    when Telegram::Bot::Types::Message then handle_message update
    when Telegram::Bot::Types::CallbackQuery then handle_callback_query update
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

    log.debug "Received message:\n#{message.to_h.pretty_inspect}"

    res =
      if message.chat.type == 'private'
        handle_private_message message
      else
        handle_group_message message
      end
    content =
      if message.text then message.text
      elsif message.sticker then '<sticker>'
      elsif message.photo then '<photo>'
      else '<unknown>'
      end
    log.info "Message handled:\n" \
      "\tChat: #{message.chat.title} @#{message.chat.username} ##{message.chat.id}" \
      "\tUser: #{message.from&.first_name} @#{message.from&.username} ##{message.from&.id}" \
      "\tContent: #{content}"
    res
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

  def handle_callback_query(query)
    log.debug 'handle_callback_query'

    log.debug "Received message:\n#{query.to_h.pretty_inspect}"

    command = CallbackCommand.parse query.data
    case command.command
    when 'add_link' then handle_callback_query_add_link query, command
    else log.warn "Unknown command: #{command.inspect}"
    end
  end

  def handle_callback_query_add_link(query, command)
    log.debug 'handle_callback_query_add_link'

    unless query.from.id == query.message.reply_to_message.from.id
      return log.warn 'Button clicked not by the message sender'
    end

    user = User.find_by tg_user_id: query.from.id

    user.update state: STATE_ADD_LINK, key_to_add: command.args[0] # key_to_add here stores the command key to update

    bot.api.edit_message_text(
      chat_id: query.message.chat.id,
      message_id: query.message.message_id,
      text: query.message.text
    )
    bot.api.answer_message query.message, text: 'Send a link or /cancel'
  end
end
