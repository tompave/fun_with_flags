# Test the performance of the persistence adapters.
# This benchmark is mostly affected by the performance of the underlying datastore.
# However, it's also useful to assess how the store is accessed in Elixir. For example,
# when switching from compiled-in config to just straight calls to the config module.

# :observer.start

Logger.configure(level: :error)

# Start the ecto repo if running the benchmarks with ecto.
if System.get_env("PERSISTENCE") == "ecto" do
  {:ok, _pid} = FunWithFlags.Dev.EctoRepo.start_link()
end

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

alias FunWithFlags.SimpleStore

# -----------------------------------
one = fn() ->
  SimpleStore.lookup(:one)
end

two = fn() ->
  SimpleStore.lookup(:two)
end

three = fn() ->
  SimpleStore.lookup(:three)
end

four = fn() ->
  SimpleStore.lookup(:four)
end


Benchee.run(
  %{
    "one" => one,
    "two" => two,
    "three" => three,
    "four" => four,
  }
)
