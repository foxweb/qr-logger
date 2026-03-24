# frozen_string_literal: true

require 'json'
require 'net/http'
require 'user_agent_parser'
require 'uri'

# Sends hit details from Rack env-derived fields (Bot API). Fails open: errors do not affect the response.
module TelegramNotify
  module_function

  MAX_MESSAGE_CHARS = 3500

  def enabled?
    t = ENV['TELEGRAM_BOT_TOKEN']
    c = ENV['TELEGRAM_CHAT_ID']
    t && !t.empty? && c && !c.empty?
  end

  def notify_hit(ip:, user_agent:, referer:, host:, url:)
    return unless enabled?

    text = format_hit(ip: ip, user_agent: user_agent, referer: referer, host: host, url: url)
    text = "#{text[0...MAX_MESSAGE_CHARS]}…" if text.length > MAX_MESSAGE_CHARS

    send_message(text)
  rescue StandardError => e
    LOGGER.error "Telegram notify error: #{e.class} - #{e.message}"
  end

  # Fire-and-forget variant so web response is not blocked by network I/O.
  def notify_hit_async(ip:, user_agent:, referer:, host:, url:)
    return unless enabled?

    Thread.new do
      Thread.current.report_on_exception = false
      notify_hit(ip: ip, user_agent: user_agent, referer: referer, host: host, url: url)
    end
  end

  def send_message(text)
    uri = telegram_send_message_uri
    req = build_send_message_request(uri, text)
    response = execute_request(uri, req)
    return if response.is_a?(Net::HTTPSuccess)

    body_preview = response.body ? response.body[0, 300] : ''
    LOGGER.warn "Telegram sendMessage failed: #{response.code} #{body_preview}"
  end

  def telegram_send_message_uri
    URI("https://api.telegram.org/bot#{ENV.fetch('TELEGRAM_BOT_TOKEN')}/sendMessage")
  end

  def build_send_message_request(uri, text)
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json; charset=utf-8'
    req.body = JSON.generate(
      'chat_id' => ENV.fetch('TELEGRAM_CHAT_ID'),
      'text' => text,
      'parse_mode' => 'HTML',
      'disable_web_page_preview' => true
    )
    req
  end

  def execute_request(uri, req)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.request(req)
    end
  end

  def format_hit(ip:, user_agent:, referer:, host:, url:)
    ua = ua_summary(user_agent)
    ref = referer.to_s.strip.empty? ? 'n/a' : referer

    <<~MSG.strip
      ✨ <b>QR Logger</b> — кто-то зашел на сайт!

      🔗 <code>#{escape_tg_html(url)}</code>
      🌐 <a href="https://ipinfo.io/#{escape_tg_html(ip)}">#{escape_tg_html(ip)}</a>
      📱 #{escape_tg_html(ua)}
      🏠 <code>#{escape_tg_html(host)}</code>
      ↩️ <b>Referer:</b> #{escape_tg_html(ref)}

      📄 <b>User-Agent:</b>
      <pre>#{escape_tg_html(user_agent)}</pre>
    MSG
  end

  def escape_tg_html(text)
    text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end

  def ua_summary(user_agent)
    parsed = UserAgentParser.parse(user_agent)
    device = parsed.device.to_s
    os = parsed.os.to_s
    browser = parsed.name.to_s
    version = parsed.version.to_s
    version_suffix = version && !version.empty? ? " #{version}" : ''
    "#{device} | #{os} | #{browser}#{version_suffix}"
  rescue StandardError
    'Unknown'
  end
end
