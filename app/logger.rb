# frozen_string_literal: true

require 'logger'

def log
  @log ||= Logger.new $stdout
end
