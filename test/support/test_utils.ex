defmodule FunWithFlags.TestUtils do
  # Since the flags are saved on shared storage (ETS and
  # Redis), in order to keep the tests isolated _and_ async
  # each test must use unique flag names. Not doing so would
  # cause some tests to override other tests flag values.
  #
  # This method should _never_ be used at runtime because
  # atoms are not garbage collected.
  #
  def unique_atom do
    :crypto.strong_rand_bytes(7)
    |> Base.encode32(padding: false, case: :lower)
    |> String.to_atom
  end
end
