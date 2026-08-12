class AppInfoController < ApplicationController
  # GET /app_info
  def show
    build = Rails.application.config.x.build_info
    @details = {
      "Git revision" => build[:git_sha] || "unknown",
      "Built at" => build[:built_at] || "unknown",
      "Rails version" => Rails.version,
      "Ruby version" => RUBY_DESCRIPTION,
      "Rack version" => Rack.release,
      "Web server" => (defined?(Raptor::VERSION) ? "Raptor #{Raptor::VERSION}" : "unknown"),
      "Environment" => Rails.env,
      "Database adapter" => ActiveRecord::Base.connection_db_config.adapter,
      "Database schema version" => ActiveRecord::Migrator.current_version.to_s
    }

    respond_to do |format|
      format.html
      format.json { render json: @details }
    end
  end
end
