# frozen_string_literal: true

require 'json'
require 'telegram/bot'
require 'dotenv'

require_relative 'bot/handlers'
require_relative 'bot/utils'
require_relative 'logger'
require_relative 'database'

Dotenv.load

# App
class App
  attr_reader :bot

  def run
    log.info 'Starting app...'
    Telegram::Bot::Client.run ENV['BOT_TOKEN'] do |bot|
      @bot = bot
      bot.api.set_my_commands commands: my_commands
      bot.listen { handle_update it }
    rescue Interrupt
      puts
      log.info 'Stopping app...'
    end
  end

  private

  def my_commands
    [{ command: 'add', description: 'Add a new command' },
     { command: 'remove', description: 'Remove a command' },
     { command: 'commands', description: 'Show all commands in chat' },
     { command: 'mycommands', description: 'Show my commands' },
     { command: 'help', description: 'Show this message' },
     { command: 'start', description: 'Start the bot' }]
  end
end

App.new.run
