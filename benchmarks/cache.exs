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


alias FunWithFlags.Store.Cache

# -----------------------------------
one = fn() ->
  Cache.get(:one)
end

two = fn() ->
  Cache.get(:two)
end

three = fn() ->
  Cache.get(:three)
end

four = fn() ->
  Cache.get(:four)
end


Benchee.run(
  %{
    "one" => one,
    "two" => two,
    "three" => three,
    "four" => four,
  }#,
  # formatters: [
  #   Benchee.Formatters.HTML,
  #   Benchee.Formatters.Console
  # ]
)
