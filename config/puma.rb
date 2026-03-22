# frozen_string_literal: true

# Minimal footprint for low-traffic / small VPS (e.g. 1 GB RAM, 1 CPU).
# Override with PUMA_THREADS_MIN / PUMA_THREADS_MAX / PORT if needed.

min_t = Integer(ENV.fetch('PUMA_THREADS_MIN', 1))
max_t = Integer(ENV.fetch('PUMA_THREADS_MAX', 1))
threads min_t, max_t

workers Integer(ENV.fetch('WEB_CONCURRENCY', 0))

port Integer(ENV.fetch('PORT', 9292))

environment ENV.fetch('RACK_ENV', 'production')
