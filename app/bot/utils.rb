# frozen_string_literal: true

class App
  def chat_commands(chat_id)
    log.debug "Fetching commands for chat #{chat_id}"
    return User.find_by(tg_user_id: chat_id)&.commands if chat_id.positive?

    chat_admins(chat_id)&.flat_map do |admin|
      log.debug "Fetching command for user #{admin.user.id}"
      if (user = User.find_by(tg_user_id: admin.user.id))
        log.debug 'Admin is registered'
        user.commands
      else
        log.debug 'Admin is not registered'
        []
      end
    end
  end

  def admin?(chat_id, user_id)
    return true if chat_id.positive?

    chat_admins(chat_id).any? { it.user.id == user_id }
  end

  def chat_admins(tg_chat_id)
    return nil if tg_chat_id.positive?

    bot.api.get_chat_administrators chat_id: tg_chat_id
  end

  def registered_admins?(chat_id)
    chat_admins(chat_id).any? { User.find_by tg_user_id: it.user.id }
  end

  def command_re
    @command_re ||= %r{^(/\w+)(@#{bot.api.get_me.username})?(\s+.+)?$}.freeze
  end
end
