defmodule GlobalId do
  @moduledoc """
  GlobalId module contains an implementation of a guaranteed globally unique ID system.
  The discussion about this solution is in the README.md file in the project root.
  """

  use Agent

  @doc """
  Keeps the final part of the global ID in a process's state. It never returns.
  """
  def start_link(initial_value) do
    Agent.start_link(fn -> initial_value end)
  end

  @doc """
  Returns a 64-bit non-negative integer. This function receives a process ID. The process is responsible for
  maintaining a state integer.
  """
  @spec get_id(pid()) :: non_neg_integer()
  def get_id(process_id) do
    Agent.update(process_id, &advance_state/1)
    current_value = Agent.get(process_id, fn current_value -> current_value end)

    unique_id(current_value)
  end

  @doc """
  Returns a globally-unique node ID as an integer.
  It will be greater than or equal to 0 and less than or equal to 1023.
  It is guaranteed to be globally unique.
  Since we don't need to implement this ourselves, I'll assume that hard-coding an ID is okay.
  """
  @spec node_id() :: non_neg_integer()
  def node_id, do: 1003

  @doc """
  Returns timestamp since the epoch in seconds.
  """
  @spec timestamp() :: non_neg_integer()
  def timestamp, do: DateTime.to_unix(DateTime.utc_now())

  @spec advance_state(non_neg_integer()) :: non_neg_integer()
  defp advance_state(current_value) when current_value < 999_999, do: current_value + 1
  defp advance_state(_), do: 0

  @spec unique_id(integer()) :: non_neg_integer()
  defp unique_id(current_value) do
    node_id() * 10_000_000_000_000_000 + timestamp() * 1_000_000 + current_value
  end
end
