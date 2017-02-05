defmodule FunWithFlags.Config do
  @default_redis_config [
    host: 'localhost',
    port: 6379,
  ]

  def redis_config do
    case Application.get_env(:fun_with_flags, :redis, []) do
      uri  when is_binary(uri) ->
        uri
      opts when is_list(opts) ->
        Keyword.merge(@default_redis_config, opts)
    end
  end
end
