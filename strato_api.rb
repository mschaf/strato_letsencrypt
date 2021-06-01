# frozen_string_literal: true

require 'rubygems'
require 'bundler/setup'
require 'capybara'
require 'capybara/dsl'
require 'selenium/webdriver'
require 'rubygems'
require 'dnsruby'


class StratoAPI

  include Dnsruby
  include Capybara::DSL

  attr_accessor :debug_prefix

  def initialize(username, password)
    @username = username
    @password = password
    @debug_prefix = ''
  end

  def set_txt_on_domain(domain:, name:, value:)
    @session = setup_capybara
    login
    select_domain(domain)
    domain_box = find_domain_box(domain)
    subdomain = (domain.split('.').length > 2)
    subdomain_created = false

    if !domain_box && subdomain
      debug('Subdomain not found, creating...')
      domain_box = create_subdomain(domain)
      debug('Subdomain created')
      subdomain_created = true
    end

    domain_box.click_on('verwalten')

    create_txt_record(name, value)

    @session.quit

    { subdomain_created: subdomain_created }
  end

  def remove_txt_on_domain(domain:, name:)
    @session = setup_capybara
    login
    select_domain(domain)
    domain_box = find_domain_box(domain)
    domain_box.click_on('verwalten')
    remove_txt_record(name)
    @session.quit
  end

  def remove_subdomain(subdomain:)
    if subdomain.split('.').length <= 2
      puts 'domain is no subdomain, not removing and quitting'
      exit 0
    end
    domain = subdomain.split('.')[-2..-1].join('.')
    @session = setup_capybara
    login
    select_domain(domain)
    domain_box = find_domain_box(subdomain)
    unless domain_box
      puts 'subdomain does not exist, quitting'
      exit 0
    end
    domain_box.click_on('verwalten')

    sleep 1
    @session.find('h4', text: 'Subdomain löschen').click
    sleep 1
    @session.find('a', text: 'Subdomain löschen', class: 'btn').click

    unless @session.all('div', text: 'Subdomain erfolgreich gelöscht').any?
      debug 'Failed to delete subdomain'
      exit -1
    end
    debug 'subdomain deleted'
    @session.quit
  end

  def wait_for_record(domain:, name:, value:)
    res = Resolver.new(nameservers: ['1.1.1.1', '8.8.8.8'])
    (0..10).each do
      result = res.query("#{name}.#{domain}", "TXT").answer.first.strings.first
      if result == value
        debug('Record found')
        return true
      end
    rescue
      debug('Record not found, waiting ...')
    end
    debug('Record finally not found')
    false
  end

  private

  def setup_capybara
    Capybara.run_server = false
    Capybara.register_driver :selenium do |app|
      browser_options = ::Selenium::WebDriver::Firefox::Options.new()
      browser_options.args << '--headless'

      Capybara::Selenium::Driver.new(
        app,
        browser: :firefox,
        options: browser_options
      )
    end
    Capybara.current_driver = :selenium
    Capybara::Session.new(:selenium)
  end

  def login
    debug('Opening Site')
    @session.visit('https://www.strato.de/apps/CustomerService')

    debug('Accepting Cookies')
    @session.click_button("Zustimmen")

    debug('Entering credentials')
    @session.fill_in('Kundennummer', with: @username)
    @session.fill_in('Passwort', with: @password)

    debug('Logging in ...')
    @session.click_button('Login')

    unless @session.find('h1', text: 'Paketübersicht')
      debug 'Login failed'
      exit -1
    end
    debug('Logged in')
  end

  def select_domain(subdomain)
    domain = subdomain.split('.')[-2..-1].join('.')
    domain_package = @session.find('div', class: 'package-information', text: domain).first(:xpath,".//..//..")
    debug('Opening domain management')
    domain_package.click_on('Domains verwalten')
    unless @session.find('h1', text: 'Domainverwaltung')
      debug 'Failed to open Domain management'
      exit -1
    end
    sleep 1
    @session.find('a', class: %w(collapsed toggle bottom)).click
  end

  def find_domain_box(domain)
    @session.find('a', text: domain, exact_text: true).first(:xpath,".//..//..")
  rescue Capybara::ElementNotFound
    false
  end

  def create_subdomain(domain)
    root_domain = domain.split('.')[-2..-1].join('.')
    subdomain = domain.split('.')[0..-3].join('.')
    domain_box = find_domain_box(root_domain)
    domain_box.click_on('verwalten')
    sleep 1
    @session.find('a', text: 'Subdomain anlegen').click
    sleep 1
    @session.find('input', id: 'create').fill_in(with: subdomain)
    sleep 0.1
    @session.find(:css, 'input[value=\'Subdomain anlegen\']').click

    unless @session.find('p', text: "Subdomain \"#{domain}\" erfolgreich angelegt.")
      debug 'Failed to create Subdomain management'
      exit -1
    end
    @session.find('a', text: 'Domainverwaltung').click
    sleep 1
    @session.find('a', class: %w(collapsed toggle bottom)).click

    find_domain_box(domain)
  end

  def create_txt_record(name, value)
    sleep 1
    begin
      @session.find('a', text: 'DNS-Verwaltung', class: 'accordion-toggle').click
    rescue
      @session.find('a', text: 'DNS Einstellungen', class: 'accordion-toggle').click
    end
    sleep 1
    @session.find('li', text: 'TXT Records inklusive SPF und DKIM Einstellungen').click_on('verwalten')
    name_input = begin
      @session.find(:css, "input[name='prefix'][value='#{name}']")
    rescue Capybara::ElementNotFound
      begin
        @session.find(:css, "input[name='prefix'][value='']")
      rescue Capybara::ElementNotFound
        @session.find('a', class: 'jss_add_row').click
        sleep 1
        @session.all(:css, "input[name='prefix']").last
      end
    end

    box = name_input.first(:xpath,".//..//..//..")
    value_input = box.find(:css, "textarea[name='value']")

    name_input.fill_in(with: name)
    value_input.fill_in(with: value)

    @session.click_on('Einstellung übernehmen')

    unless @session.all('div', text: 'Ihre Aktion wurde erfolgreich ausgeführt.').any?
      debug 'Failed to set TXT record'
      exit -1
    end
  end

  def remove_txt_record(name)
    sleep 1
    begin
      @session.find('a', text: 'DNS-Verwaltung', class: 'accordion-toggle').click
    rescue
      @session.find('a', text: 'DNS Einstellungen', class: 'accordion-toggle').click
    end
    sleep 1
    @session.find('li', text: 'TXT Records inklusive SPF und DKIM Einstellungen').click_on('verwalten')
    sleep 1

    name_input = begin
      @session.find(:css, "input[name='prefix'][value='#{name}']")
    rescue Capybara::ElementNotFound
      puts 'TXT record not found, were done here'
      return
    end

    debug 'Removing record'
    box = name_input.first(:xpath,".//..//..//..")
    box.find('a', class: 'jss_delete_row').click
    sleep 1

    debug 'Saving changes'
    @session.click_on('Einstellung übernehmen')

    unless @session.all('div', text: 'Ihre Aktion wurde erfolgreich ausgeführt.').any?
      debug 'Failed to set TXT record'
      exit -1
    end
    debug 'Removed txt record'
  end

  def debug(text)
    puts debug_prefix + text
  end

end
