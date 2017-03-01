defimpl FunWithFlags.Actor, for: Map do
  def id(%{actor_id: actor_id}) do
    "map:#{actor_id}"
  end

  def id(map) do
    id =
      map
      |> inspect()
      |> Base.encode32(padding: false, case: :lower)
    "map:#{id}"
  end
end
