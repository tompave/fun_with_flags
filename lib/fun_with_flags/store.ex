defmodule FunWithFlags.Store do
  @moduledoc false
  alias FunWithFlags.Store.{Cache, Persistent}
  alias FunWithFlags.Config

  def lookup(flag_name) do
    do_lookup(flag_name, with_cache: Config.cache?)
  end


  def put(flag_name, value) do
    do_put(flag_name, value, with_cache: Config.cache?)
  end


  defp do_lookup(flag_name, with_cache: true) do
    case Cache.get(flag_name) do
      :not_found ->
        case Persistent.get(flag_name) do
          {:error, _reason} ->
            false
          bool when is_boolean(bool) ->
            # {:ok, ^bool} = Cache.put(flag_name, bool)
            # swallow cache errors for the moment
            Cache.put(flag_name, bool) 
            bool
        end
      {:found, value} ->
        value
    end
  end


  defp do_lookup(flag_name, with_cache: false) do
    case Persistent.get(flag_name) do
      {:error, _reason} ->
        false
      bool when is_boolean(bool) ->
        bool
    end
  end


  defp do_put(flag_name, value, with_cache: true) do
    case Persistent.put(flag_name, value) do
      {:ok, ^value} ->
        Cache.put(flag_name, value)
      {:error, _reason} = error ->
        error
    end
  end


  defp do_put(flag_name, value, with_cache: false) do
    Persistent.put(flag_name, value)
  end

end
