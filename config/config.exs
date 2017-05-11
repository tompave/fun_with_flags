use Mix.Config

case Mix.env do
  :test -> import_config "test.exs"
  _     -> nil
end
