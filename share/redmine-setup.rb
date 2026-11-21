# frozen_string_literal: true

# Runs after the migrations, in the same rake process (see redmine-update and
# lib/tasks/wodby.rake): the migrations create Redmine's stock administrator
# (login "admin", password "admin"), and the account gets its real password a
# moment later, not after another Rails boot.

def say(message)
  puts "[redmine-update] #{message}"
end

def fail!(message)
  warn "[redmine-update] #{message}"
  exit 1
end

# The migrations used some models before their tables were complete.
Rails.application.eager_load!
ActiveRecord::Base.descendants.each(&:reset_column_information)

language = ENV['REDMINE_LANG'].to_s.strip
language = 'en' if language.empty?

# Trackers, statuses, roles, workflows and priorities, once.
if Redmine::DefaultData::Loader.no_data?
  unless ::I18n.available_locales.map(&:to_s).include?(language)
    fail! "Unknown language #{language.inspect}; use one of #{::I18n.available_locales.join(', ')}"
  end

  Redmine::DefaultData::Loader.load(language)
  say "Loaded the default configuration in #{language}"
end

# The first administrator replaces the stock one while it still has the
# password "admin", or is created when the database has no administrator. An
# account changed in Redmine is never touched again.
admin = User.find_by(login: 'admin', admin: true)
admin = nil unless admin&.check_password?('admin')
if admin.nil? && !User.where(admin: true).exists?
  admin = User.new(firstname: 'Redmine', lastname: 'Admin', mail_notification: 'all')
  admin.admin = true
end
if admin
  password = ENV['REDMINE_ADMIN_PASSWORD'].to_s
  login = ENV['REDMINE_ADMIN_LOGIN'].to_s.strip
  email = ENV['REDMINE_ADMIN_EMAIL'].to_s.strip

  lock_stock_admin = lambda do
    admin.reload.update_columns(status: User::STATUS_LOCKED) if admin.persisted?
  end

  if password.empty?
    lock_stock_admin.call
    fail! 'REDMINE_ADMIN_PASSWORD is empty: no administrator can sign in until it is set'
  end

  admin.login = login.empty? ? 'admin' : login
  admin.mail = email unless email.empty?
  admin.mail = "#{admin.login}@example.invalid" if admin.mail.blank?
  admin.password = password
  admin.password_confirmation = password
  admin.language = language
  admin.must_change_passwd = false
  admin.status = User::STATUS_ACTIVE
  # No security notifications to the stock account's placeholder address.
  saved = Mailer.with_deliveries(false) { admin.save }
  unless saved
    errors = admin.errors.full_messages.join('; ')
    lock_stock_admin.call
    fail! "The administrator was not saved: #{errors}. No administrator can sign in until the settings are fixed"
  end
  say "Set up the administrator #{admin.login}"
end

# The address Redmine uses in links of its emails, until set in Redmine.
url = ENV['REDMINE_HOST_URL'].to_s.strip
url = ENV['WODBY_PRIMARY_URL'].to_s.strip if url.empty?
if !url.empty? && !Setting.where(name: 'host_name').exists?
  uri = URI.parse(url)
  if uri.host
    host = uri.host
    host += ":#{uri.port}" unless uri.port == uri.default_port
    host += uri.path.chomp('/')
    Setting.host_name = host
    Setting.protocol = uri.scheme
    say "Set the host name to #{uri.scheme}://#{host}"
  end
end

# The sender of Redmine's emails, until set in Redmine.
mail_from = ENV['REDMINE_MAIL_FROM'].to_s.strip
if !mail_from.empty? && !Setting.where(name: 'mail_from').exists?
  Setting.mail_from = mail_from
  say "Set the email sender to #{mail_from}"
end
