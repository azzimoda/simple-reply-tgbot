# frozen_string_literal: true

require 'json'

require 'telegram/bot/api'

class Telegram::Bot::Api
  def answer_message(message, reply: false, **params)
    params[:reply_parameters] = { message_id: message.message_id }.to_json if reply

    send_message(chat_id: message.chat.id, message_thread_id: message.message_thread_id, **params)
  end
end
