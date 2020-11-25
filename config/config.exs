[
  sansa: [
      oanda: [
          token_file: "data/oanda_token",
          account_id_file: "data/oanda_account"
      ],
      trading: [
          spread_max: %{
              "AUD_JPY" => 1.8,
              "EUR_CHF" => 2.0,
              "GBP_AUD" => 4.2,
              "NZD_CAD" => 2.9,
              "CAD_CHF" => 2.8,
              "EUR_USD" => 1.5,
              "GBP_USD" => 2.0,
              "USD_CHF" => 2.0,
              "EUR_JPY" => 2.0,
              "NZD_JPY" => 2.0,
              "AUD_CHF" => 2.6,
              "GBP_CAD" => 4.2,
              "USD_CAD" => 2.0,
              "AUD_USD" => 1.8,
              "NZD_USD" => 2.5,
              "EUR_AUD" => 3.1,
              "EUR_GBP" => 2.5,
              "GBP_CHF" => 2.8,
              "GBP_JPY" => 3.0,
              "USD_JPY" => 1.5,
              "AUD_NZD" => 3.0,
              "AUD_CAD" => 2.5,
              "CHF_JPY" => 2.7,
              "CAD_JPY" => 2.0,
              "EUR_NZD" => 3.4,
              "EUR_CAD" => 2.5,
              "GBP_NZD" => 4.5,
              "NZD_CHF" => 2.7

          },
          rrp: 1.3,
          risque: 0.015,
          paires: [
            "AUD_JPY",
            "EUR_CHF",
            "GBP_AUD",
            "NZD_CAD",
            "CAD_CHF",
            "EUR_USD",
            "GBP_USD",
            "USD_CHF",
            "EUR_JPY",
            "NZD_JPY",
            "AUD_CHF",
            "GBP_CAD",
            "USD_CAD",
            "AUD_USD",
            "NZD_USD",
            "EUR_AUD",
            "EUR_GBP",
            "GBP_CHF",
            "GBP_JPY",
            "USD_JPY",
            "AUD_NZD",
            "AUD_CAD",
            "CHF_JPY",
            "CAD_JPY",
            "EUR_NZD",
            "EUR_CAD",
            "GBP_NZD",
            "NZD_CHF"
            ],
        strats: %{"H1" =>
        [
            {%{name: :ema_cross, rrp: 3, stop_placement: :regular_atr}, "NZD_JPY"},
            {%{name: :ema_cross, rrp: 3, stop_placement: :tight_atr}, "GBP_USD"},
            {%{name: :macd_cross, rrp: 3, stop_placement: :tight_atr}, "NZD_CHF"},
            {%{name: :ss_ema, rrp: 3, stop_placement: :regular_atr}, "EUR_USD"},
            {%{name: :ss_ema, rrp: 3, stop_placement: :regular_atr}, "CAD_JPY"},
            {%{name: :ss_ema, rrp: 3, stop_placement: :regular_atr}, "USD_JPY"},
            {%{name: :ss_ema, rrp: 3, stop_placement: :very_tight}, "GBP_CAD"},
            {%{name: :ich_cross, rrp: 2, stop_placement: :regular_atr}, "EUR_NZD"}
        ],
        "M15" =>
        []
        }
  ]],
  logger: [
      backends: [{LoggerFileBackend, :info_log}, {LoggerFileBackend, :debug_log}, :console],
      info_log: [
          path: "logfile.log",
          level: :info
      ],
      debug_log: [
          path: "logfile_debug.log",
          level: :debug
      ]
  ]
]
# "USD_CAD",
#     "AUD_USD",
#     "NZD_USD",
#     "EUR_AUD",
#     "EUR_GBP",
#     "GBP_CHF",
#     "GBP_JPY",
#     "USD_JPY",
#     "AUD_NZD",
#     "AUD_CAD",
#     "CHF_JPY",
#     "CAD_JPY",
#     "EUR_NZD",
#     "EUR_CAD",
#     "GBP_NZD",
#     "NZD_CHF"
