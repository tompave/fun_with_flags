# :observer.start

# Start the ecto repo if running the benchmarks with ecto.
# {:ok, _pid} = FunWithFlags.Dev.EctoRepo.start_link()

FunWithFlags.clear(:one)
FunWithFlags.clear(:two)
FunWithFlags.clear(:three)
FunWithFlags.clear(:four)

alias PlainUser, as: User

u1 = %User{id: 1, group: "foo"}
u2 = %User{id: 2, group: "foo"}
u3 = %User{id: 3, group: "bar"}
u4 = %User{id: 4, group: "bar"}

FunWithFlags.enable(:one)

FunWithFlags.enable(:two)
FunWithFlags.enable(:two, for_actor: u4)
FunWithFlags.disable(:two, for_group: "nope")

FunWithFlags.disable(:three)
FunWithFlags.enable(:three, for_actor: u2)
FunWithFlags.enable(:three, for_actor: u3)
FunWithFlags.enable(:three, for_actor: u4)
FunWithFlags.disable(:three, for_group: "nope")
FunWithFlags.disable(:three, for_group: "nope2")


FunWithFlags.disable(:four)
FunWithFlags.enable(:four, for_actor: u2)
FunWithFlags.enable(:four, for_actor: u3)
FunWithFlags.enable(:four, for_actor: u4)
FunWithFlags.enable(:four, for_actor: "a")
FunWithFlags.enable(:four, for_actor: "b")
FunWithFlags.enable(:four, for_actor: "c")
FunWithFlags.enable(:four, for_actor: "d")
FunWithFlags.enable(:four, for_actor: "e")
FunWithFlags.disable(:four, for_group: "nope")
FunWithFlags.disable(:four, for_group: "nope2")
FunWithFlags.disable(:four, for_group: "nope3")
FunWithFlags.disable(:four, for_group: "nope4")
FunWithFlags.enable(:four, for_percentage_of: {:actors, 0.99})

# warm up the cache
FunWithFlags.enabled?(:one)
FunWithFlags.enabled?(:two)
FunWithFlags.enabled?(:three)
FunWithFlags.enabled?(:four)

# -----------------------------------
one_a = fn() ->
  FunWithFlags.enabled?(:one)
end

one_b = fn() ->
  FunWithFlags.enabled?(:one, for: u1)
end

two_a = fn() ->
  FunWithFlags.enabled?(:two)
end

two_b = fn() ->
  FunWithFlags.enabled?(:two, for: u1)
end

three_a = fn() ->
  FunWithFlags.enabled?(:three)
end

three_b = fn() ->
  FunWithFlags.enabled?(:three, for: u1)
end

four_a = fn() ->
  FunWithFlags.enabled?(:four)
end

four_b = fn() ->
  FunWithFlags.enabled?(:four, for: u1)
end

Benchee.run(
  %{
    "one_a" => one_a,
    "one_b" => one_b,
    "two_a" => two_a,
    "two_b" => two_b,
    "three_a" => three_a,
    "three_b" => three_b,
    "four_a" => four_a,
    "four_b" => four_b,
  }#,
#   formatters: [
#     Benchee.Formatters.HTML,
#     Benchee.Formatters.Console
#   ]
)
