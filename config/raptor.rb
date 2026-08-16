# This configuration file is evaluated by Raptor and must return a hash.
# For the full list of options see https://github.com/joshuay03/raptor.
#
# No pid_file here: `rails server` writes tmp/pids/server.pid itself, and
# Raptor refuses to start if its pid_file already exists.
#
# On macOS, run via bin/dev (or export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
# first): Raptor forks workers, and Apple's ObjC runtime otherwise kills any
# forked worker that makes an HTTP call.

env = ENV.fetch("RAILS_ENV", "development")

# Match Active Record's pool size (database.yml) to avoid connection starvation.
threads = Integer(ENV.fetch("RAILS_MAX_THREADS", 3))

# One worker per processor in production, single process otherwise.
workers =
  if env == "production"
    Integer(ENV.fetch("WEB_CONCURRENCY") { require "etc"; Etc.nprocessors })
  else
    1
  end

config = {
  binds: ["tcp://0.0.0.0:#{ENV.fetch("PORT", 3000)}"],
  workers: workers,
  threads: threads,
  environment: env,
}

# Don't reap workers parked at a debugger breakpoint in development.
config[:worker_timeout] = 3600 if env == "development"

config
