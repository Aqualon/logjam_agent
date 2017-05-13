# frozen_string_literal: true
module LogjamAgent
  class Middleware
    def initialize(app, options={})
      @app = app
      @options = options
    end

    def call(env)
      strip_encoding_from_etag(env)
      request = start_request(env)
      result = @app.call(env)
      result[1] ||= {}
      result
    rescue Exception
      result = [500, {'Content-Type' => 'text/html'}, ["<html><body><h1>500 Internal Server Error</h1>"]]
    ensure
      headers = result[1]
      headers["X-Logjam-Request-Id"] = request.id
      unless (request_action = request.fields[:action]).blank?
        headers["X-Logjam-Request-Action"] = request_action
      end
      unless (caller_id = request.fields[:caller_id]).blank?
        headers["X-Logjam-Caller-Id"] = caller_id
      end
      finish_request(env)
    end

    private

    def strip_encoding_from_etag(env)
      # In some versions, Apache is appending the content encoding,
      # like gzip to the ETag-Response-Header, which will cause the
      # Rack::ConditionalGet middleware to never match.
      if env["HTTP_IF_NONE_MATCH"] =~ /\A(.*)-\w+(\")\z/
        env["HTTP_IF_NONE_MATCH"] = $1 + $2
      end
    end

    def start_request(env)
      app_name      = env["logjam_agent.application_name"] || LogjamAgent.application_name
      env_name      = env["logjam_agent.environment_name"] || LogjamAgent.environment_name
      caller_id     = env["HTTP_X_LOGJAM_CALLER_ID"] || ""
      caller_action = env["HTTP_X_LOGJAM_ACTION"] || ""
      LogjamAgent.start_request(app_name, env_name, :caller_id => caller_id, :caller_action => caller_action)
    end

    def finish_request(env)
      LogjamAgent.finish_request(env["time_bandits.metrics"])
    end
  end
end
