# frozen_string_literal: true

namespace :wodby do
  desc 'Load the default configuration, set up the first administrator and the host name (see redmine-update)'
  task setup: :environment do
    load '/usr/local/share/wodby/redmine-setup.rb'
  end
end
