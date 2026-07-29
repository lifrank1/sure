# Runs Sidekiq inside the Puma process when SIDEKIQ_EMBEDDED=true, replacing
# the separate Railway worker service — one Rails boot (~330 MB) instead of
# two. Sidekiq.configure_embed replays every Sidekiq.configure_server block
# (sidekiq-cron's poller prepend + schedule.yml loader, sentry-sidekiq,
# config/initializers/sidekiq.rb), so cron schedules and error reporting work
# with no initializer changes.
require "puma/plugin"

Puma::Plugin.create do
  def start(launcher)
    return unless ENV["SIDEKIQ_EMBEDDED"] == "true"

    # In cluster mode on_booted fires in the master, which must never run
    # jobs. Production runs single mode (WEB_CONCURRENCY unset); refuse
    # loudly rather than embed in the wrong process.
    if launcher.options[:workers].to_i > 0
      launcher.log_writer.log "! sidekiq_embed: cluster mode detected, refusing to embed. Unset WEB_CONCURRENCY or move to on_worker_boot."
      return
    end

    embedded = nil

    launcher.events.on_booted do
      # Rails is fully booted here, so all configure_server blocks are
      # registered before configure_embed replays them.
      embedded = Sidekiq.configure_embed do |config|
        config.concurrency = Integer(ENV.fetch("SIDEKIQ_EMBEDDED_CONCURRENCY", 2))
        # Embed mode ignores config/sidekiq.yml — mirror its weighted queues.
        config.queues = %w[scheduled,10 high_priority,4 medium_priority,2 low_priority,1 default,1]
        # Graceful-stop deadline for in-flight jobs. Must fit inside
        # RAILWAY_DEPLOYMENT_DRAINING_SECONDS alongside Puma's HTTP drain,
        # or Railway SIGKILLs and unfinished jobs are lost instead of
        # re-enqueued.
        config[:timeout] = Integer(ENV.fetch("SIDEKIQ_EMBEDDED_TIMEOUT", 20))
      end
      embedded.run
      launcher.log_writer.log "* sidekiq_embed: running (concurrency=#{ENV.fetch("SIDEKIQ_EMBEDDED_CONCURRENCY", 2)})"
    rescue => e
      # Job infra failing must not take the web app down with it. This is
      # loud in logs + Sentry; jobs simply don't process until fixed.
      launcher.log_writer.log "! sidekiq_embed: FAILED TO START — no jobs will process: #{e.class}: #{e.message}"
      Sentry.capture_exception(e) if defined?(Sentry)
      embedded = nil
    end

    # on_stopped fires at the start of Puma's graceful stop: Sidekiq quiets,
    # waits up to :timeout for in-flight jobs, then pushes stragglers back
    # to Redis (at-least-once) before Puma drains HTTP.
    #
    # Puma fires these from its signal handler (trap context), where mutex
    # acquisition raises ThreadError ("can't be called from trap context") —
    # Sidekiq's poller shutdown takes a connection-pool mutex. Spawning a
    # thread and joining it moves the stop out of trap context.
    stop_embedded = -> { Thread.new { embedded&.stop }.join }
    launcher.events.on_stopped(&stop_embedded)
    launcher.events.on_restart(&stop_embedded)
  end
end
