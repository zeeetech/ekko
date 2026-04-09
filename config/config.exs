import Config

config :ekko,
  verify_requests: true,
  cert_cache_ttl_ms: 86_400_000,
  timestamp_tolerance_seconds: 150

if File.exists?(Path.join(__DIR__, "#{config_env()}.exs")) do
  import_config "#{config_env()}.exs"
end
