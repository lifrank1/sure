if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = ENV["RAILS_ENV"]
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
    config.enabled_environments = %w[production]

    # Enable sending logs to Sentry
    config.enable_logs = true
    # Patch Ruby logger to forward logs
    config.enabled_patches = [ :logger ]

    # Error reporting only. Tracing/profiling held live sample buffers during
    # exactly the long job batches that drive peak memory — and nobody reads
    # the performance dashboards on this instance. Re-enable by env var if
    # that changes.
    #
    # Leave the rates UNSET (nil) rather than 0: sentry-ruby treats 0.0 as
    # "tracing configured", which keeps the whole transaction/span pipeline
    # installed and lets any client force-sample via a sentry-trace header;
    # nil disables the pipeline entirely.
    if ENV["SENTRY_TRACES_SAMPLE_RATE"].present?
      config.traces_sample_rate = Float(ENV["SENTRY_TRACES_SAMPLE_RATE"])
    end
    if ENV["SENTRY_PROFILES_SAMPLE_RATE"].present?
      config.profiles_sample_rate = Float(ENV["SENTRY_PROFILES_SAMPLE_RATE"])
    end

    config.release = Rails.root.join(".sure-version").read.strip rescue nil
    config.profiler_class = Sentry::Vernier::Profiler
  end
end
