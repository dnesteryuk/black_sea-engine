# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :bolt_sips, Bolt,
  url: System.get_env("NEO4J_URL") || "bolt://localhost:7687",
  ssl: System.get_env("NEO4J_SSL") || false,
  pool_size: System.get_env("NEO4J_POOL_SIZE") || 20,
  max_overflow: System.get_env("NEO4J_MAX_OVERFLOW") || 10,
  timeout: System.get_env("NEO4J_TIMEOUT") || 15_000

config :sirko, :web,
  port: System.get_env("SIRKO_HTTP_PORT") || 4000,
  # the address of a site for which predictions should be made
  client_url: System.get_env("SIRKO_CLIENT_URL")

# Settings for sort of an internal CRON (https://en.wikipedia.org/wiki/Cron)
config :sirko, :scheduler,
  # how often the scheduler should be launched to expire inactive sessions
  expire_sessions_every: 3600 * 1000,
  # how often the scheduler should be launched to remove stale data
  remove_stale_data_every: 3600 * 1000 * 24

# Settings which affect the behavior of the engine. These settings are used by different parts of the engine.
# To get more details about them, read the prod config: config/sirko.toml
config :sirko, :engine,
  inactive_session_in: 3600 * 1000,
  stale_session_in: 3600 * 1000 * 24 * 7,
  confidence_threshold: 0.2,
  max_pages_in_prediction: 1

config :logger, :console,
  level: (System.get_env("SIRKO_DEBUG_LEVEL") || "info") |> String.to_atom(),
  format: "$date $time [$level] $metadata$message\n"

config :rollbax,
  environment: Mix.env() |> Atom.to_string(),
  # give it an empty string to avoid failures in the dev and test env
  access_token: "",
  enabled: false

import_config "#{Mix.env()}.exs"
