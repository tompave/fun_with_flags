use Mix.Config

case Mix.env do
  :test          -> import_config "test.exs"
  :test_no_cache -> import_config "test_no_cache.exs"
  _              -> nil
end
