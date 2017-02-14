defmodule FunWithFlags.SimpleStore do
  @moduledoc false

  alias FunWithFlags.Store.Persistent


  def lookup(flag_name) do
    case Persistent.get(flag_name) do
      {:error, _reason} ->
        false
      bool when is_boolean(bool) ->
        bool
    end
  end


  def put(flag_name, value) do
    Persistent.put(flag_name, value)
  end
end
