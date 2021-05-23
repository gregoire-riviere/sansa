defmodule Sansa.PriceAction do

  require Logger

  @otz_search_depth 20
  @atr_mean 200

  defp frequencies(enumerable) do
    reduce(enumerable, %{}, fn key, acc ->
      case acc do
        %{^key => value} -> %{acc | key => value + 1}
        %{} -> Map.put(acc, key, 1)
      end
    end)
  end

  def compute_otz(prices) do
    agg_value = prices |> Enum.map(& &1.atr) |> Enum.reverse |> Enum.take(@atr_mean) |> Enum.sum
    agg_value = agg_value/@atr_mean
    maxs_mins = prices |> Enum.chunk_every(@otz_search_depth, 1, :discard) |> Enum.map(fn window ->
      p = Enum.map(window, & &1.close)
      [
        Enum.max(p),
        Enum.min(p)
      ]
    end) |> List.flatten |> compute_weigths(agg_value) |> recursive_agg(agg_value)
  end

  def compute_weigths(maxs_mins, agg_value) do
    maxs_mins |> Enum.map(fn v -> {Enum.count(maxs_mins, & &1 <= v + agg_value/2 && &1 >= v - agg_value/2), v} end) |> Enum.uniq
  end

  def recursive_agg(maxs_mins, agg_value, acc \\ []) do
    Logger.debug("#{inspect agg_value}")
    case maxs_mins do
      [] -> acc
      l ->
        val = maxs_mins |> Enum.sort_by(fn {w, _} -> w end) |> Enum.reverse |> hd
        recursive_agg(
          Enum.reject(maxs_mins, & elem(&1, 1) <= elem(val, 1) + 1.5*agg_value && elem(&1, 1) >= elem(val, 1) - 1.5*agg_value),
          agg_value,
          acc ++ [val]
        )
    end |> Enum.sort_by(& elem(&1, 0)) |> Enum.reverse
  end
end
