require 'dotenv/tasks'
require_relative './lib/humane_society'

namespace :humane_society do
  desc "Send updated dog listings text"
  task send_updated_dogs_text: :dotenv do
    DogManager.new.run
  end
end
