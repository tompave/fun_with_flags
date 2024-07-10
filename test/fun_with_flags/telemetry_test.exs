defmodule FunWithFlags.TelemetryTest do
  use FunWithFlags.TestCase, async: false
  import FunWithFlags.TestUtils
  import TelemetryTest
  import Mock

  setup [:telemetry_listen]

  describe ":enable telemetry" do
    setup do
       scrooge = %FunWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp", groups: [:ducks, :billionaires]}
       donald = %FunWithFlags.TestUser{id: 2, email: "donald@duck.db", groups: [:ducks, :super_heroes]}
       {:ok, scrooge: scrooge, donald: donald, flag_name: unique_atom()}
     end

     @tag telemetry_listen: [:fun_with_flags, :flag_operation]
     test "emits telemetry event when enabling a flag", %{flag_name: flag_name} do
       FunWithFlags.enable(flag_name)

       assert_received {:telemetry_event, %{
         measurements: %{duration: _},
         event: [:fun_with_flags, :flag_operation],
         metadata: %{
           options: [],
           result: {:ok, true},
           flag_name: ^flag_name,
           operation: :enable
         }
       }}
     end

     @tag telemetry_listen: [:fun_with_flags, :flag_operation]
     test "emits telemetry event when enabling a flag for an actor", %{flag_name: flag_name, scrooge: scrooge} do
       FunWithFlags.enable(flag_name, for_actor: scrooge)

       assert_received {:telemetry_event, %{
         measurements: %{duration: _},
         event: [:fun_with_flags, :flag_operation],
         metadata: %{
           options: [for_actor: ^scrooge],
           result: {:ok, true},
           flag_name: ^flag_name,
           operation: :enable
         }
       }}
     end

     @tag telemetry_listen: [:fun_with_flags, :flag_operation]
     test "emits telemetry event when enabling a flag for a group", %{flag_name: flag_name} do
       group_name = :test_group
       FunWithFlags.enable(flag_name, for_group: group_name)

       assert_received {:telemetry_event, %{
         measurements: %{duration: _},
         event: [:fun_with_flags, :flag_operation],
         metadata: %{
           options: [for_group: ^group_name],
           result: {:ok, true},
           flag_name: ^flag_name,
           operation: :enable
         }
       }}
     end

     @tag telemetry_listen: [:fun_with_flags, :flag_operation]
     test "emits telemetry event when enabling a flag for percentage of time", %{flag_name: flag_name} do
       ratio = 0.5
       FunWithFlags.enable(flag_name, for_percentage_of: {:time, ratio})

       assert_received {:telemetry_event, %{
         measurements: %{duration: _},
         event: [:fun_with_flags, :flag_operation],
         metadata: %{
           options: [for_percentage_of: {:time, ^ratio}],
           result: {:ok, true},
           flag_name: ^flag_name,
           operation: :enable
         }
       }}
     end

     @tag telemetry_listen: [:fun_with_flags, :flag_operation]
     test "emits telemetry event when enabling a flag for percentage of actors", %{flag_name: flag_name} do
       ratio = 0.5
       FunWithFlags.enable(flag_name, for_percentage_of: {:actors, ratio})

       assert_received {:telemetry_event, %{
         measurements: %{duration: _},
         event: [:fun_with_flags, :flag_operation],
         metadata: %{
           options: [for_percentage_of: {:actors, ^ratio}],
           result: {:ok, true},
           flag_name: ^flag_name,
           operation: :enable
         }
       }}
     end
  end

  describe "enabled? telemetry" do
    setup do
      scrooge = %FunWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp", groups: [:ducks, :billionaires]}
      donald = %FunWithFlags.TestUser{id: 2, email: "donald@duck.db", groups: [:ducks, :super_heroes]}
      flag_name = unique_atom()
      {:ok, scrooge: scrooge, donald: donald, flag_name: flag_name}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when checking an enabled flag", %{flag_name: flag_name} do
      FunWithFlags.enable(flag_name)


      FunWithFlags.enabled?(flag_name)

      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [],
          result: true,
          flag_name: ^flag_name,
          operation: :enabled?
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when checking a disabled flag", %{flag_name: flag_name} do
      FunWithFlags.disable(flag_name)


      FunWithFlags.enabled?(flag_name)

      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [],
          result: false,
          flag_name: ^flag_name,
          operation: :enabled?
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when checking an enabled flag for a specific actor", %{flag_name: flag_name, scrooge: scrooge} do
      FunWithFlags.enable(flag_name, for_actor: scrooge)

      FunWithFlags.enabled?(flag_name, for: scrooge)

      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [for: ^scrooge],
          result: true,
          flag_name: ^flag_name,
          operation: :enabled?
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when checking a disabled flag for a specific actor", %{flag_name: flag_name, donald: donald} do
      FunWithFlags.enable(flag_name)
      FunWithFlags.disable(flag_name, for_actor: donald)
      FunWithFlags.enabled?(flag_name, for: donald)

      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [for: ^donald],
          result: false,
          flag_name: ^flag_name,
          operation: :enabled?
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when checking an enabled flag for a group", %{flag_name: flag_name, scrooge: scrooge} do
      group = :billionaires
      FunWithFlags.enable(flag_name, for_group: group)


      result = FunWithFlags.enabled?(flag_name, for: scrooge)

      assert result == true
      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [for: ^scrooge],
          result: true,
          flag_name: ^flag_name,
          operation: :enabled?
        }
      }}
    end
  end

  describe "disable telemetry" do
    setup do
      scrooge = %FunWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp", groups: [:ducks, :billionaires]}
      donald = %FunWithFlags.TestUser{id: 2, email: "donald@duck.db", groups: [:ducks, :super_heroes]}
      flag_name = unique_atom()
      {:ok, scrooge: scrooge, donald: donald, flag_name: flag_name}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when disabling a flag globally", %{flag_name: flag_name} do
      FunWithFlags.enable(flag_name)


      result = FunWithFlags.disable(flag_name)

      assert result == {:ok, false}
      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [],
          result: {:ok, false},
          flag_name: ^flag_name,
          operation: :disable
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when disabling a flag for an actor", %{flag_name: flag_name, scrooge: scrooge} do
      FunWithFlags.enable(flag_name, for_actor: scrooge)


      result = FunWithFlags.disable(flag_name, for_actor: scrooge)

      assert result == {:ok, false}
      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [for_actor: ^scrooge],
          result: {:ok, false},
          flag_name: ^flag_name,
          operation: :disable
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when disabling a flag for a group", %{flag_name: flag_name} do
      group = :billionaires
      FunWithFlags.enable(flag_name, for_group: group)


      result = FunWithFlags.disable(flag_name, for_group: group)

      assert result == {:ok, false}
      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [for_group: ^group],
          result: {:ok, false},
          flag_name: ^flag_name,
          operation: :disable
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when disabling a flag for a percentage of time", %{flag_name: flag_name} do
      ratio = 0.5
      FunWithFlags.enable(flag_name, for_percentage_of: {:time, ratio})


      result = FunWithFlags.disable(flag_name, for_percentage_of: {:time, ratio})

      assert result == {:ok, false}
      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [for_percentage_of: {:time, ^ratio}],
          result: {:ok, false},
          flag_name: ^flag_name,
          operation: :disable
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when disabling a flag for a percentage of actors", %{flag_name: flag_name} do
      ratio = 0.5
      FunWithFlags.enable(flag_name, for_percentage_of: {:actors, ratio})


      result = FunWithFlags.disable(flag_name, for_percentage_of: {:actors, ratio})

      assert result == {:ok, false}
      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [for_percentage_of: {:actors, ^ratio}],
          result: {:ok, false},
          flag_name: ^flag_name,
          operation: :disable
        }
      }}
    end
  end

  describe "clear telemetry" do
    setup do
      scrooge = %FunWithFlags.TestUser{id: 1, email: "scrooge@mcduck.pdp", groups: [:ducks, :billionaires]}
      donald = %FunWithFlags.TestUser{id: 2, email: "donald@duck.db", groups: [:ducks, :super_heroes]}
      flag_name = unique_atom()
      {:ok, scrooge: scrooge, donald: donald, flag_name: flag_name}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when clearing a flag globally", %{flag_name: flag_name} do
      FunWithFlags.enable(flag_name)


      result = FunWithFlags.clear(flag_name)

      assert result == :ok
      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [],
          result: :ok,
          flag_name: ^flag_name,
          operation: :clear
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when clearing a boolean gate", %{flag_name: flag_name} do
      FunWithFlags.enable(flag_name)


      result = FunWithFlags.clear(flag_name, boolean: true)

      assert result == :ok
      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [boolean: true],
          result: :ok,
          flag_name: ^flag_name,
          operation: :clear
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when clearing a flag for an actor", %{flag_name: flag_name, scrooge: scrooge} do
      FunWithFlags.enable(flag_name, for_actor: scrooge)


      result = FunWithFlags.clear(flag_name, for_actor: scrooge)

      assert result == :ok
      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [for_actor: ^scrooge],
          result: :ok,
          flag_name: ^flag_name,
          operation: :clear
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when clearing a flag for a group", %{flag_name: flag_name} do
      group = :billionaires
      FunWithFlags.enable(flag_name, for_group: group)


      result = FunWithFlags.clear(flag_name, for_group: group)

      assert result == :ok
      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [for_group: ^group],
          result: :ok,
          flag_name: ^flag_name,
          operation: :clear
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when clearing a percentage gate", %{flag_name: flag_name} do
      FunWithFlags.enable(flag_name, for_percentage_of: {:time, 0.5})


      result = FunWithFlags.clear(flag_name, for_percentage: true)

      assert result == :ok
      assert_received {:telemetry_event, %{
        measurements: %{duration: _},
        event: [:fun_with_flags, :flag_operation],
        metadata: %{
          options: [for_percentage: true],
          result: :ok,
          flag_name: ^flag_name,
          operation: :clear
        }
      }}
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when clearing fails globally", %{flag_name: flag_name} do
      error_reason = {:error, :test_error}

      with_mock FunWithFlags.Store, [:passthrough], [delete: fn(_) -> error_reason end] do
        result = FunWithFlags.clear(flag_name)

        assert result == error_reason
        assert_received {:telemetry_event, %{
          measurements: %{duration: _},
          event: [:fun_with_flags, :flag_operation],
          metadata: %{
            options: [],
            result: ^error_reason,
            flag_name: ^flag_name,
            operation: :clear
          }
        }}
      end
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when clearing fails for an actor", %{flag_name: flag_name, scrooge: scrooge} do
      error_reason = {:error, :test_error}

      with_mock FunWithFlags.Store, [:passthrough], [delete: fn(_, _) -> error_reason end] do
        result = FunWithFlags.clear(flag_name, for_actor: scrooge)

        assert result == error_reason
        assert_received {:telemetry_event, %{
          measurements: %{duration: _},
          event: [:fun_with_flags, :flag_operation],
          metadata: %{
            options: [for_actor: ^scrooge],
            result: ^error_reason,
            flag_name: ^flag_name,
            operation: :clear
          }
        }}
      end
    end

    @tag telemetry_listen: [:fun_with_flags, :flag_operation]
    test "emits telemetry event when clearing fails for a group", %{flag_name: flag_name} do
      error_reason = {:error, :test_error}
      group = :billionaires

      with_mock FunWithFlags.Store, [:passthrough], [delete: fn(_, _) -> error_reason end] do
        result = FunWithFlags.clear(flag_name, for_group: group)

        assert result == error_reason
        assert_received {:telemetry_event, %{
          measurements: %{duration: _},
          event: [:fun_with_flags, :flag_operation],
          metadata: %{
            options: [for_group: ^group],
            result: ^error_reason,
            flag_name: ^flag_name,
            operation: :clear
          }
        }}
      end
    end
  end

end
