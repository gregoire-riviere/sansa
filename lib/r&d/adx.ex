#   def adx_range(list_price, nb_periods \\ 14) do
#     if Enum.count(list_price) <= nb_periods do
#         Logger.error("Nb of periods too large!")
#         list_price
#     else
#         {first_prices, last_prices} = Enum.split(list_price, nb_periods-1)
#         first_prices = Enum.map(first_prices, &
#             put_in(&1, [:tr_range], 0) |>
#             put_in([:dmi_plus], 0) |>
#             put_in([:dmi_moins], 0)
#         )
#         last_prices = Enum.chunk(list_price, nb_periods, 1, :discard) |> Enum.map(fn l_p ->
#            maxi = Enum.map(l_p, & &1[:high]) |> Enum.max
#            mini = Enum.map(l_p, & &1[:low]) |> Enum.min
#            tr_range = abs(maxi-mini)
#            dmi_plus = 100 * (Enum.map(l_p, & &1[:di_plus]) |> Enum.sum) / tr_range
#            dmi_moins = 100 * (Enum.map(l_p, & &1[:di_moins]) |> Enum.sum) / tr_range
#            l_p |> Enum.reverse |> hd
#            |> put_in([:dmi_plus], dmi_plus)
#            |> put_in([:dmi_moins], dmi_moins)
#         end)
#         first_prices ++ last_prices
#     end
#   end

    # def tr_range(list_price, nb_periods \\ 14) do
    #     if Enum.count(list_price) <= nb_periods do
    #         Logger.error("Nb of periods too large!")
    #         list_price
    #     else
    #         {first_prices, last_prices} = Enum.split(list_price, nb_periods-1)
    #         first_prices = Enum.map(first_prices, & put_in(&1, [:tr_range], 0))
    #         last_prices = Enum.chunk(list_price, nb_periods, 1, :discard) |> Enum.map(fn l_p ->
    #         maxi = Enum.map(l_p, & &1[:high]) |> Enum.max
    #         mini = Enum.map(l_p, & &1[:low]) |> Enum.min
    #         l_p |> Enum.reverse |> hd |> put_in([:tr_range], abs(maxi-mini))
    #         end)
    #         first_prices ++ last_prices
    #     end
    # end
#   def adx(list_prices) do
#     list_prices |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [prev, cur] ->
#         Map.put(cur, :mt_plus, cur.high - prev.high) |>
#         Map.put(:mt_moins, prev.low - cur.low)
#     end) |> Enum.map(fn p->
#         p = Map.put(p, :dmt_plus, (if (p.mt_plus > p.mt_moins && p.mt_plus > 0), do: p.mt_plus, else: 0)) |>
#         Map.put(:dmt_moins, (if (p.mt_moins > p.mt_plus && p.mt_moins >0), do: p.mt_moins, else: 0)) #|>
#         # Map.pop(:mt_plus) |> elem(1) |> Map.pop(:mt_moins) |> elem(1)
#     end)
#     |> ema(14, :dmt_plus, :di_plus)
#     |> ema(14, :dmt_moins, :di_moins)
#     |> tr_range(14)
#     |> Enum.map(fn p->
#         p = put_in(p, [:di_plus], p.tr_range != 0 && 100*p.di_plus/p.tr_range || 0) |>
#         put_in([:di_moins], p.tr_range != 0 && 100*p.di_moins/p.tr_range || 0) #|>
#         # pop_in([:dmt_plus]) |> elem(1) |>
#         # pop_in([:dmt_moins]) |> elem(1)
#     end) |> Enum.map(fn p ->
#        if p.di_plus != 0 && p.di_moins != 0 do
#             put_in(p, [:dxi], 100 * (abs(p.di_plus - p.di_moins) / (p.di_plus + p.di_moins)))
#        else put_in(p, [:dxi], 0) end
#     end) |> ema(14, :dxi, :adx)
#   end

    # def adx(list_prices) do
    #     list_prices |> Enum.chunk_every(2, 1, :discard) |> Enum.map(fn [prev, cur] ->
    #         Map.put(cur, :mt_plus, cur.high - prev.high) |>
    #         Map.put(:mt_moins, prev.low - cur.low)
    #     end) |> Enum.map(fn p->
    #         p = Map.put(p, :di_plus, (if (p.mt_plus > p.mt_moins && p.mt_plus > 0), do: p.mt_plus, else: 0)) |>
    #         Map.put(:di_moins, (if (p.mt_moins > p.mt_plus && p.mt_moins >0), do: p.mt_moins, else: 0)) #|>
    #         # Map.pop(:mt_plus) |> elem(1) |> Map.pop(:mt_moins) |> elem(1)
    #     end)
    #     # |> ema(14, :dmt_plus, :di_plus)
    #     # |> ema(14, :dmt_moins, :di_moins)
    #     |> adx_range(14)
    #     |> Enum.map(fn p ->
    #         put_in(p, [:dxi], abs(p.dmi_plus - p.dmi_moins))
    #     end) |> ema(14, :dxi, :adx)
    # end
