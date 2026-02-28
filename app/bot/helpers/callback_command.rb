# frozen_string_literal: true

# Callback query command
class CallbackCommand
  class << self
    def parse(data)
      command, *args = data.split("\n")
      new command, *args
    end
  end

  attr_reader :command, :args

  def initialize(command, *args)
    @command = command
    @args = args
  end

  def to_s
    "#{@command}\n#{@args.join("\n")}"
  end
end
