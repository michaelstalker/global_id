defmodule GlobalIdTest do
  use ExUnit.Case
  use ExUnitProperties

  describe "throughput" do
    property "handles at least 100_000 requests per second" do
      check all pid <- constant(spawn(GlobalId, :loop, [0])),
                request_count <- integer(10..500_000),
                max_runs: 20 do
        runner = fn ->
          Enum.each(1..request_count, fn _ -> GlobalId.get_id(pid) end)
        end
        {microseconds, _} = :timer.tc(runner)
        seconds = microseconds / 1_000_000

        assert request_count / seconds >= 100_000
      end
    end
  end

  describe "uniqueness" do
    property "each ID is unique" do
      check all pid <- constant(spawn(GlobalId, :loop, [0])),
                request_count <- integer(10..500_000),
                max_runs: 20 do
        ids = Enum.map(1..request_count, fn _ -> GlobalId.get_id(pid) end)

        assert length(Enum.uniq(ids)) == request_count
      end
    end

    test "each ID is unique even when we generate ten million IDs" do
      pid = spawn(GlobalId, :loop, [0])
      ids = Enum.map(1..10_000_000, fn _ -> GlobalId.get_id(pid) end)

      assert length(Enum.uniq(ids)) == 10_000_000
    end
  end

  describe "ID size and type" do
    property "returns a positive 64-bit integer" do
      check all pid <- constant(spawn(GlobalId, :loop, [0])),
                request_count <- integer(10..500_000),
                max_runs: 20 do
        ids = Enum.map(1..request_count, fn _ -> GlobalId.get_id(pid) end)

        assert Enum.all?(ids, &valid_id?/1)
      end
    end
  end

  defp valid_id?(id), do: is_integer(id) && id > 0 && id < :math.pow(2, 64)
end
