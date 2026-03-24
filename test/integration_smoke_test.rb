# frozen_string_literal: true

require 'json'
require 'minitest/autorun'

# Minimal constants/modules required by HitLogApp in isolation.
HOSTNAMES = ['localhost'].freeze unless defined?(HOSTNAMES)
REDIRECT_TO = 'https://example.org/'.freeze unless defined?(REDIRECT_TO)
VERSION = 'test'.freeze unless defined?(VERSION)

module Admin
  def self.call(_env)
    [200, { 'content-type' => 'text/plain' }, ['admin']]
  end
end unless defined?(Admin)

module Database
  module_function

  def health_check
    { status: 'ok', database: 'connected' }
  end

  def log_hit(**_args)
    true
  end
end unless defined?(Database)

require_relative '../app/hit_log_app'

class IntegrationSmokeTest < Minitest::Test
  def setup
    @app = HitLogApp.new
  end

  def test_health_endpoint_returns_ok
    response = @app.call(base_env(path: '/health'))

    assert_equal 200, response[0]
    payload = JSON.parse(response[2].join)
    assert_equal 'healthy', payload['status']
    assert_equal 'connected', payload['database']
  end

  def test_hit_endpoint_redirects_logs_and_schedules_telegram
    log_hit_args = nil
    notify_args = nil

    Database.singleton_class.send(:define_method, :log_hit) do |**args|
      log_hit_args = args
      true
    end

    TelegramNotify.singleton_class.send(:define_method, :notify_hit_async) do |**args|
      notify_args = args
      true
    end

    response = @app.call(
      base_env(
        path: '/y',
        query: 'utm=test',
        ip: '203.0.113.10',
        user_agent: 'Mozilla/5.0 TestBrowser/1.0',
        referer: 'https://ref.example/'
      )
    )

    assert_equal 302, response[0]
    assert_equal REDIRECT_TO, response[1]['location']
    refute_nil log_hit_args
    refute_nil notify_args
    assert_equal '203.0.113.10', log_hit_args[:ip]
    assert_equal 'https://localhost/y?utm=test', notify_args[:url]
  end

  private

  def base_env(path:, query: '', ip: '127.0.0.1', user_agent: 'TestAgent', referer: '')
    {
      'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => path,
      'QUERY_STRING' => query,
      'SCRIPT_NAME' => '',
      'HTTP_HOST' => 'localhost',
      'REMOTE_ADDR' => ip,
      'HTTP_USER_AGENT' => user_agent,
      'HTTP_REFERER' => referer
    }
  end
end
