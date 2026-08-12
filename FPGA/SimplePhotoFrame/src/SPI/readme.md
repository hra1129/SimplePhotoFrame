# SPI Slave Controller (`ip_spi.v`) 仕様

## 1. 概要

`ip_spi.v` は、マイクロコントローラからの SPI 通信を FPGA 内部の 16 bit I/O レジスタバスへ変換する SPI slave controller である。

主な動作は次のとおり。

1. SPI のコマンド、I/O アドレス、データを受信する。
2. SPI アドレス 1 byte を I/O 番号とレジスタ番号に分解する。
3. I/O 番号を one-hot の `bus_cs[7:0]` に変換し、下位 5 bit を `bus_address` として出力する。
4. I/O write では受信した 16 bit データを内部バスへ発行する。
5. I/O read では内部バスの応答を待ち、16 bit データを SPI へ返す。
6. I/O status read では指定 I/O の `bus_ready` を 1 byte で返す。

SPI の 1 トランザクションは `spi_cs_n` が Low の期間に完結させる。`spi_cs_n` が High になると、コマンド解析状態、SPI byte 処理、内部バス要求を初期状態へ戻す。

## 2. モジュールインターフェース

### クロック／リセット

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `clk` | input | 1 | システムクロック。内部 FSM とバスの基準クロック |
| `clk_serial` | input | 1 | SPI 信号同期用クロック |
| `reset` | input | 1 | High active リセット |

SPI 入力信号は `clk_serial` ドメインで 2 段 FF を通して取り込む。`spi_cs_n`、`spi_clk`、`spi_mosi` の非同期入力に対するメタステーブル耐性を確保する。

### 内部 I/O バスマスター

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `bus_cs` | output | 8 | I/O 選択。one-hot |
| `bus_write` | output | 1 | High: write、Low: read |
| `bus_valid` | output | 1 | バス要求有効 |
| `bus_ready` | input | 1 | 選択 I/O が要求を受理可能 |
| `bus_wdata` | output | 16 | 書き込みデータ |
| `bus_address` | output | 5 | 選択 I/O 内のレジスタ番号 |
| `bus_rdata` | input | 16 | 読み出しデータ |
| `bus_rdata_en` | input | 1 | 読み出しデータ有効 |

`bus_cs` が 0 の場合、`ip_spi` は内部バスが常に ready とみなして次の SPI 解析へ進む。I/O read の場合は `bus_valid` を保持し、`bus_rdata_en` を受信するまで SPI の応答 byte 送信へ進まない。

### SPI インターフェース

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `spi_cs_n` | input | 1 | SPI slave select。Low active |
| `spi_clk` | input | 1 | SPI serial clock |
| `spi_mosi` | input | 1 | Master Out Slave In |
| `spi_miso` | output | 1 | Master In Slave Out |
| `spi_intr` | output | 1 | 送信 byte 準備完了通知 |

SPI は Mode 0（CPOL=0、CPHA=0）、8 bit、MSB first で使用する。1 byte の送受信が終わるたびに上位 FSM が次の byte の送受信要求を `spi.v` へ発行する。

## 3. SPI コマンド表

SPI コマンドは、`spi_cs_n` を Low にした後、先頭 byte として送信する。

| コマンド | 名称 | 送受信フレーム | 動作 |
|---:|---|---|---|
| `0x01` | `CMD_IO_WRITE` | `command, address, data_l, data_h` | 指定 I/O レジスタへ 16 bit 書き込み |
| `0x02` | `CMD_IO_READ` | `command, address, dummy, dummy` | 指定 I/O レジスタから 16 bit 読み出し |
| `0x03` | `CMD_IO_STATUS` | `command, address, dummy` | 指定 I/O の ready 状態を 1 byte 読み出し |

データ byte の順序は little-endian である。write は下位 byteを先に送信し、read は下位 byte、上位 byte の順で MISO から受信する。

## 4. SPI アドレス形式

2 byte 目の `address` は、上位 3 bit を I/O 番号、下位 5 bit を I/O 内レジスタ番号として使用する。

```text
address[7:5] = I/O number 0 .. 7
address[4:0] = register address 0 .. 31
```

I/O 番号は次の one-hot 信号へ変換される。

| `address[7:5]` | `bus_cs` | 選択 I/O |
|---:|---:|---:|
| `3'b000` | `8'h01` | I/O #0 |
| `3'b001` | `8'h02` | I/O #1 |
| `3'b010` | `8'h04` | I/O #2 |
| `3'b011` | `8'h08` | I/O #3 |
| `3'b100` | `8'h10` | I/O #4 |
| `3'b101` | `8'h20` | I/O #5 |
| `3'b110` | `8'h40` | I/O #6 |
| `3'b111` | `8'h80` | I/O #7 |

従って、例えば SPI address `8'hC3` は I/O #6、レジスタ `0x03` を選択する。

## 5. 各コマンドの動作

### 5.1 I/O write (`0x01`)

フレーム形式は次のとおり。

```text
MOSI: command, address, data[7:0], data[15:8]
```

`data[15:8]` を受信した時点で、次の内部バス要求を生成する。

```text
bus_cs      = one_hot(address[7:5])
bus_address = address[4:0]
bus_write   = 1
bus_wdata   = { data[15:8], data[7:0] }
bus_valid   = 1
```

内部 I/O が `bus_ready = 1` を返すまで `bus_valid` を保持する。`bus_ready` が Low の場合、SPI master は `spi_cs_n` を Low のまま保持して待つ必要がある。要求が受理されると、トランザクションは完了する。

### 5.2 I/O read (`0x02`)

フレーム形式は次のとおり。

```text
MOSI: command, address, 0x00, 0x00
MISO:          dummy,   dummy, data[7:0], data[15:8]
```

address を受信すると内部バス read 要求を発行する。`bus_rdata_en = 1` になるまで応答 byte の準備を待つ。

バス応答を受信すると、次の順序で MISO へ送信する。

1. `bus_rdata[7:0]`
2. `bus_rdata[15:8]`

read 応答の準備が SPI master の送信タイミングに間に合わない場合は、`spi_intr` を利用して送信可能状態を確認する。

### 5.3 I/O status read (`0x03`)

フレーム形式は次のとおり。

```text
MOSI: command, address, 0x00
MISO:          dummy,   ready_status
```

address を受信した時点で、選択 I/O の `bus_ready` を取得する。応答 byte は次の形式である。

```text
response[0] = selected_io_bus_ready
response[7:1] = 0
```

内部実装では 16 bit の応答値 `{7'd0, bus_ready, 8'd0}` の上位 byte が送信されるため、SPI 上の status byte では ready 状態が bit 0 に現れる。

なお、選択 I/O がなく `bus_cs = 0` の場合は ready とみなされる。通常の status read では、address byte に I/O 番号とレジスタ番号を指定するが、status 判定に使われるのは I/O 番号である。

## 6. 内部動作

### 6.1 SPI byte 受付

`ip_spi` は `spi.v` に 1 byte 単位の送受信要求を発行する。`spi_valid` が High の要求は、`spi_ready` が High のときに受理される。受信 byte は `spi_rdata_en` とともに `ip_spi` へ渡され、送信 byte は `spi_tx_load_en` でシフタへロードされたことが通知される。

SPI の受信 byte はコマンド解析、アドレス受信、データ受信の各状態で順番に取り込む。送信時は、内部データを下位 byte と上位 byte に分けて 1 byte ずつロードする。

### 6.2 FSM の状態

| 状態 | 動作 |
|---|---|
| `ST_IDLE` | 次のコマンド byte の受信要求を準備 |
| `ST_COMMAND` | コマンド byte を解析し、write／read／status read に分岐 |
| `ST_ADDRESS` | I/O 番号とレジスタ番号を受信し、`bus_cs` と `bus_address` を生成 |
| `ST_WDATA_L` | write データ下位 byte を受信 |
| `ST_WDATA_H` | write データ上位 byte を受信し、内部バス write を発行 |
| `ST_BUS_READ` | 内部バス read 応答 `bus_rdata_en` を待つ |
| `ST_RDATA_L` | read データ下位 byte を SPI 送信用シフタへロード |
| `ST_RDATA_H` | read データ上位 byte、または status byte を送信用シフタへロード |

`spi_cs_n` が High になると、どの状態からでも `ST_IDLE` 相当の初期状態へ戻り、未完了の `bus_valid` と SPI 要求を解除する。

### 6.3 内部バス要求の保持

I/O write はデータ受信完了後に `bus_valid` を High にする。`bus_ready` が Low の間は要求を保持し、受理されたクロックで `bus_valid` を解除する。

I/O read は address 受信後に `bus_valid = 1`、`bus_write = 0` として要求を保持する。`bus_rdata_en` を受信してから read data を SPI 送信へ渡す。

### 6.4 SPI 割り込み

`spi_intr` は、read 応答 byte が SPI シフタへ実際にロードされたタイミングで High になる。最初の MISO bit を master が読み出せる状態になったことを通知する。

`spi_intr` は、次のいずれかで Low になる。

- `spi_cs_n` が High になる。
- `spi_intr` が High の状態で SPI clock が検出される。
- リセットが発生する。

I/O read の応答待ちでは、SPI master は `spi_intr = 1` を待ってから dummy byte の clock を出す。write やコマンド／アドレス受信の送信データ準備通知には通常使用しない。

## 7. SPI 通信上の注意

- `spi_cs_n` は 1 トランザクション中 Low を維持する。
- コマンド、address、データ byte の間で `spi_cs_n` を High にすると、トランザクションは破棄される。
- SPI の byte 順序は MSB first、16 bit データの byte 順序は low byte first である。
- I/O read では、内部バス応答が返るまで read data 用 dummy byte の送信を待つ。
- I/O が busy の場合、write は `bus_ready` が High になるまで完了しない。
- `CMD_IO_STATUS` を連続して使用する場合も、各フレームで対象 I/O address byte を送る必要がある。
- SPI clock は `clk_serial` ドメインで同期化されるため、SPI master の clock 周波数と `clk_serial` の関係を FPGA のタイミング制約に含める。

## 8. リセット後の状態

- FSM はコマンド待ち状態。
- `bus_cs` は 0。
- `bus_valid` は 0。
- SPI 送受信要求は無効。
- `spi_intr` は Low。
- `spi_miso` の送信シフトレジスタは 0。
