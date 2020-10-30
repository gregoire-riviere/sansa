[
  sansa: [
      oanda: [
          token_file: "data/oanda_token",
          account_id_file: "data/oanda_account"
      ],
      trading: [
          taille_pour_mille: %{
              "AUD_JPY" => 0.083,
              "EUR_CHF" => 0.093,
              "GBP_AUD" => 0.061,
              "NZD_CAD" => 0.068,
              "CAD_CHF" => 0.094,
              "EUR_USD" => 0.091,
              "GBP_USD" => 0.091,
              "USD_CHF" => 0.094,
              "EUR_JPY" => 0.084,
              "NZD_JPY" => 0.084,
              "AUD_CHF" => 0.094,
              "GBP_CAD" => 0.068,
              "USD_CAD" => 0.065,
              "AUD_USD" => 0.091,
              "NZD_USD" => 0.091,
              "EUR_AUD" => 0.06,
              "EUR_GBP" => 0.11,
              "GBP_CHF" => 0.093,
              "GBP_JPY" => 0.082,
              "USD_JPY" => 0.082
          },
          position_pip: %{
              "AUD_JPY" => 0.01,
              "EUR_CHF" => 0.0001,
              "GBP_AUD" => 0.0001,
              "NZD_CAD" => 0.0001,
              "CAD_CHF" => 0.0001,
              "EUR_USD" => 0.0001,
              "USD_JPY" => 0.01,
              "GBP_USD" => 0.0001,
              "USD_CHF" => 0.0001,
              "EUR_JPY" => 0.01,
              "NZD_JPY" => 0.01,
              "AUD_CHF" => 0.0001,
              "GBP_CAD" => 0.0001,
              "USD_CAD" => 0.0001,
              "AUD_USD" => 0.0001,
              "NZD_USD" => 0.0001,
              "EUR_AUD" => 0.0001,
              "EUR_GBP" => 0.0001,
              "GBP_CHF" => 0.0001,
              "GBP_JPY" => 0.01
          },
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
              "USD_JPY" => 1.5

          },
          rrp: 1.3,
          risque: 0.015,
          paires: ["EUR_USD", "CAD_CHF", "GBP_AUD", "NZD_JPY", "USD_CHF"]
          # paires: [
          #     {"NZD_JPY", :tcsc_strat},
          #     {"USD_JPY", :tcsc_strat}
          # ]
      ]
  ],
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
