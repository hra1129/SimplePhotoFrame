# 概要
bus_selector.v は、DisplayController（読み出し専用）と Cache（読み書き・リフレッシュ）の
2つの要求元から、単一の SDRAM インターフェース（32bit, 8word バースト）への要求を
調停するモジュールである。

# バス構成
bus_selector.v には、3種類のバスインターフェースがある。

- Display 側インターフェース（sdram_display_*）：読み出し専用。
- Cache 側インターフェース（sdram_cache_*）：読み出し・書き込み・リフレッシュに対応。
- SDRAM インターフェース（sdram_*）：Display / Cache の要求を調停した結果を出力する、実際の SDRAM Controller 側インターフェース。

いずれも、DRAM の 32bit 8word バースト単位（アドレスは [22:5]）でアクセスする。

# インターフェース仕様（Display側）
|信号名|方向|内容|
|--|--|--|
|sdram_display_address[22:5]|入力|読み出し先頭アドレス|
|sdram_display_address_valid|入力|1:読み出し要求あり|
|sdram_display_address_ready|出力|1:読み出し要求受理|
|sdram_display_rdata[31:0]|出力|読み出しデータ|
|sdram_display_rdata_valid|出力|読み出しデータ有効|

# インターフェース仕様（Cache側）
|信号名|方向|内容|
|--|--|--|
|sdram_cache_address[22:5]|入力|アクセス先頭アドレス|
|sdram_cache_write|入力|1:書き込み, 0:読み出し|
|sdram_cache_refresh|入力|1:リフレッシュ要求|
|sdram_cache_address_valid|入力|1:アクセス要求あり|
|sdram_cache_address_ready|出力|1:アクセス要求受理|
|sdram_cache_wdata[31:0]|入力|書き込みデータ|
|sdram_cache_wdata_mask[3:0]|入力|byte単位書き込みマスク|
|sdram_cache_wdata_valid|入力|書き込みデータ有効|
|sdram_cache_rdata[31:0]|出力|読み出しデータ|
|sdram_cache_rdata_valid|出力|読み出しデータ有効|

sdram_cache_refresh=1 の場合、sdram_cache_write の値にかかわらずリフレッシュ要求として扱う。

# インターフェース仕様（SDRAM側）
|信号名|方向|内容|
|--|--|--|
|sdram_address[22:5]|出力|アクセス先頭アドレス|
|sdram_write|出力|1:書き込み, 0:読み出し|
|sdram_refresh|出力|1:リフレッシュ要求|
|sdram_address_valid|出力|要求有効|
|sdram_address_ready|入力|要求受理|
|sdram_wdata[31:0]|出力|書き込みデータ|
|sdram_wdata_mask[3:0]|出力|byte単位書き込みマスク|
|sdram_wdata_valid|出力|書き込みデータ有効|
|sdram_rdata[31:0]|入力|読み出しデータ|
|sdram_rdata_valid|入力|読み出しデータ有効|

# 調停ロジック
Display / Cache のどちらか一方のみ valid の場合は、その要求をそのまま選択する。

Display / Cache が同時に valid の場合は、前回受理した側と反対側を優先するラウンドロビン方式
（ff_rr_turn）で交互に選択する。要求を受理する（w_active が成立する）たびに、
ff_rr_turn は選択されなかった側を指すように更新される。

選択された要求は、SDRAM Controller 側が受理可能（sdram_address_ready=1）になったタイミングで
実際に SDRAM インターフェースへ出力される。

# 読み出し・書き込みバースト処理
要求が SDRAM Controller に受理されると、要求元に応じて以下のいずれかの状態に遷移し、
1回のバースト（8word）が完了するまで新たな要求の受理を待たせる。

- 読み出し要求（Display の要求、または Cache の読み出し要求）の場合、sdram_rdata_valid が
  8回アサートされるまで読み出しバースト中として扱う（ff_read_stall）。読み出したデータは、
  要求元（ff_read_bus に記録）に応じて sdram_display_rdata / sdram_cache_rdata のいずれかに
  振り分けられる。
- 書き込み要求（Cache の書き込み要求）の場合、sdram_cache_wdata_valid が8回アサートされる
  までを書き込みバースト中として扱う（ff_write_stall）。

要求が SDRAM Controller に受理される前に一時的にビジー状態（sdram_address_ready=0）に
なった場合に備えて、受理待ちであったことを記録し（ff_read_seen_busy / ff_write_seen_busy）、
実際にデータが流れ始めるまでバーストの受理判定を続けるフェイルセーフ処理を行う。

# プリフェッチ機構
読み出しバースト中（ff_read_stall）、かつ最初の読み出しデータが到着した後
（ff_read_data_started）で、まだ次の要求を確保していない場合、Display / Cache から
新たな要求（読み出しのみ。Cache の書き込み・リフレッシュ要求は対象外）が来ていれば、
その要求を ff_prefetch_* に先読みして確保する（w_prefetch_capture）。
確保した要求元の Display または Cache には、通常の受理タイミングを待たずに
sdram_display_address_ready / sdram_cache_address_ready を返す。

先読みした要求は、現在のバーストが完了して bus_selector がアイドルになった直後に、
通常の要求受理よりも優先して SDRAM Controller へ発行される（w_prefetch_issue）。
これにより、連続する読み出し要求の間で SDRAM Controller への発行が途切れず、
読み出しスループットが向上する。

# リセット時の初期化
リセット中は ff_ready=0 となり、Display / Cache いずれの要求も受理しない。
リセット解除後、最初に SDRAM Controller が要求を受理可能になったタイミングで
要求の受理を開始する。
