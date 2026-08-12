# Build metadata for the /app_info page. In production the Docker build bakes
# GIT_SHA and BUILT_AT into the image; in development we fall back to git.
Rails.application.config.x.build_info = {
  git_sha: ENV["GIT_SHA"].presence || `git rev-parse --short HEAD 2>/dev/null`.strip.presence,
  built_at: ENV["BUILT_AT"].presence
}
