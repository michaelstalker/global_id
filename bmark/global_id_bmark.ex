defmodule GlobalIdBmark do
  use Bmark

  bmark :runner do
    {:ok, pid} = GlobalId.start_link(0)
    Enum.each(1..1_000_000, fn _ -> GlobalId.get_id(pid) end)
  end
end
