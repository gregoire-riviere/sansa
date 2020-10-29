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
              "USD_JPY" => 0.087,
              "GBP_USD" => 0.091,
              "USD_CHF" => 0.094,
              "EUR_JPY" => 0.084,
              "NZD_JPY" => 0.084,
              "AUD_CHF" => 0.094,
              "GBP_CAD" => 0.068,
              "USD_CAD" => 0.065,
              "AUD_USD" => 0.091,
              "NZD_USD" => 0.091,

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
          },
          spread_max: %{
              "AUD_JPY" => 2.0,
              "EUR_CHF" => 2.0,
              "GBP_AUD" => 4.2,
              "NZD_CAD" => 2.9,
              "CAD_CHF" => 2.8,
              "EUR_USD" => 1.5,
              "USD_JPY" => 1.5,
              "GBP_USD" => 2.0,
              "USD_CHF" => 2.0,
              "EUR_JPY" => 2.0,
              "NZD_JPY" => 2.0,
              "AUD_CHF" => 2.6,
              "GBP_CAD" => 4.2,
              "USD_CAD" => 2.0,
              "AUD_USD" => 3.0,
              "NZD_USD" => 3.3,
          },
          rrp: 1.3,
          risque: 0.015,
          paires: [
              {"NZD_JPY", :tcsc_strat},
              {"USD_JPY", :tcsc_strat}
          ]
      ],
      backtest: [
          backtest_mode: true,
          step_for_ut: %{
              "H1"=> 3600,
              "H4"=> 3600*4
          },
          start_ts: 1491908811,
          # stop_ts: 1546297200,
          paires: ["AUD_USD", "NZD_USD", "EUR_JPY", "NZD_JPY", "AUD_CHF", "GBP_CAD", "AUD_JPY", "EUR_CHF", "GBP_AUD", "NZD_CAD", "EUR_USD", "CAD_CHF", "USD_JPY", "GBP_USD", "USD_CHF", "USD_CAD"]
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
