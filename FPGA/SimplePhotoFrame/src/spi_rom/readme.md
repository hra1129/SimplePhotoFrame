# SPI Serial ROM Controller (`ip_spi_rom.v`) 仕様

## 1. 概要

`ip_spi_rom` は、FPGA 内部の 8 bit レジスタバスから外部 SPI serial flash ROM を操作するコントローラである。アドレス設定、単 byte read、256 byte burst read／write、chip erase、status read、write enable、block erase、接続 ROM 選択を提供する。

主な動作は次のとおり。

1. command port に内部コマンドを書き込む。
2. 必要に応じて data port へ 24 bit ROM アドレス、データ、ROM 番号を渡す。
3. コマンドに対応する SPI flash コマンド、アドレス、dummy byte、データを外部 ROM へ発行する。
4. ROM から読み出した byte を `bus_rdata` と `bus_rdata_en` で内部バスへ返す。
5. コマンド実行中は `bus_ready` を Low にし、完了後に High へ戻す。

外部 ROM は 2 個まで接続でき、`srom0_cs_n` または `srom1_cs_n` のいずれかを Low にして選択する。初期状態では両方の CS が High で、ROM は未選択である。

## 2. モジュールインターフェース

### クロック／リセット

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `reset` | input | 1 | High active システムリセット |
| `clk` | input | 1 | 内部バスおよびコマンド FSM の基準クロック |
| `clk_serial` | input | 1 | SPI serial 信号処理用の高速クロック |

### 内部バス

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `bus_cs` | input | 1 | 本モジュール選択 |
| `bus_address` | input | 1 | command port または data port の選択 |
| `bus_write` | input | 1 | High: write、Low: read |
| `bus_valid` | input | 1 | バス要求有効 |
| `bus_ready` | output | 1 | 要求受付可能 |
| `bus_wdata` | input | 8 | 書き込みデータ |
| `bus_rdata` | output | 8 | 読み出しデータ |
| `bus_rdata_en` | output | 1 | 読み出しデータ有効パルス |

`bus_address = 0` は command port、`bus_address = 1` は data port である。`bus_cs && bus_valid` を受理した後、コマンド実行中は `bus_ready` を Low にする。読み出しデータは `bus_rdata_en` が High の 1 クロックで有効となる。

### 外部 SPI serial flash ROM

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `srom0_cs_n` | output | 1 | ROM #0 chip select。Low active |
| `srom1_cs_n` | output | 1 | ROM #1 chip select。Low active |
| `srom_clk` | output | 1 | SPI serial clock |
| `srom_hold_n` | inout | 1 | HOLD#。通常は High／非使用 |
| `srom_wp_n` | inout | 1 | WP#。通常は High／非使用 |
| `srom_do` | inout | 1 | Serial data out。ROM の出力 |
| `srom_di` | inout | 1 | Serial data in。ROM への入力 |

通常の write、address、dummy、erase 操作は標準 SPI 1-bit モードで行う。read data 取得時は標準 read モードへ切り替えて ROM の data out を取り込む。

## 3. ポートとアドレス

### 3.1 command port (`bus_address = 0`)

command port への write で、以後の data port の意味と実行する SPI flash 操作を選択する。command port の read は使用しない。

### 3.2 data port (`bus_address = 1`)

data port は command mode に応じて、24 bit アドレスの入力、データの入力、ROM data の出力、status の出力、ROM 選択に使用される。

## 4. コマンド表

| command | 名称 | data port の用途 | 外部 SPI flash 操作 |
|---:|---|---|---|
| `0x00` | `SET_ADDRESS` | 3 byte のアドレス入力 | 外部アクセスなし |
| `0x01` | `SINGLE_READ` | 1 byte read | `FAST_READ (0x0B)` + 24 bit address + dummy |
| `0x02` | `BURST_READ` | 1 byte read を連続実行 | 初回に `FAST_READ (0x0B)`、以後同一 CS で連続 read |
| `0x03` | `BURST_WRITE` | 1 byte write を連続実行 | `WRITE_ENABLE (0x06)` + `PAGE_PROGRAM (0x02)` |
| `0x04` | `CHIP_ERASE` | 使用しない | `WRITE_ENABLE (0x06)` + `CHIP_ERASE (0x60)` |
| `0x05` | `READ_STATUS` | 1 byte read | `READ_STATUS_1 (0x05)` |
| `0x06` | `SELECT_SROM` | ROM 番号 write | 外部アクセスなし |
| `0x07` | `ACCESS_END` | 使用しない | SPI ROM idle 待ち後に CS を解除 |
| `0x08` | `WRITE_ENABLE` | 使用しない | `WRITE_ENABLE (0x06)` |
| `0x09` | `BLOCK_ERASE` | 使用しない | `WRITE_ENABLE` + `BLOCK_ERASE (0xD8)` + 24 bit address |
| `0x0A` | `READ_STATUS_2` | 1 byte read | `READ_STATUS_2 (0x35)` |
| `0x0B`～`0x0E`、`0x10`～`0xFF` | reserved | 使用しない | NOP。直前の command mode は実行しない |

## 5. 各コマンドの詳細

### 5.1 `SET_ADDRESS` (`0x00`)

data port へ 3 byte を順番に write して、24 bit ROM アドレスを設定する。入力順は下位 byteからである。

```text
1 byte目 -> rom_address[7:0]
2 byte目 -> rom_address[15:8]
3 byte目 -> rom_address[23:16]
```

3 byte 未満の状態で command port に `0x00` を再度 write すると、次の data port write は 1 byte 目から始まる。アドレス設定だけでは外部 ROM への SPI transfer は発生しない。

### 5.2 `SINGLE_READ` (`0x01`)

data port を read するたびに、設定済みアドレスを使って以下の操作を実行する。

```text
FAST_READ (0x0B)
address[23:16], address[15:8], address[7:0]
dummy byte
read data byte
```

read data は `bus_rdata` に出力され、`bus_rdata_en` が 1 クロック High になる。コマンド完了後、ROM アドレスを 1 増加する。次の data port read は次のアドレスから新しい SPI read transaction を開始する。

### 5.3 `BURST_READ` (`0x02`)

command port に `0x02` を write した時点では、外部 SPI transfer はまだ開始しない。最初の data port read で `FAST_READ`、24 bit address、dummy byte を発行し、その後 ROM の CS を保持したまま read data を取得する。

- 1 回の data port read は 1 byte を返す。
- 内部 burst counter は 8 bit で、最大 256 byte を連続して扱う。
- burst 開始時はアドレス下位 byte を `0x00` にそろえる。
- 各 byte の完了後、ROM アドレスを 1 増加する。
- `bus_ready` は各 byte の処理完了後に戻る。

burst を終了するときは `ACCESS_END` (`0x07`) を command port に write し、SPI ROM が idle になった後で CS を解除する。

### 5.4 `BURST_WRITE` (`0x03`)

command port に `0x03` を write すると、内部アドレスの下位 byte は `0x00` にそろえられ、burst write counter は 0 に戻る。その後 data port に write された byte を順番に page program する。

最初の data port write では、次の処理を開始する。

```text
WRITE_ENABLE (0x06)
PAGE_PROGRAM (0x02)
address[23:16], address[15:8], address[7:0]
write data byte
```

2 byte 目以降の data port write は、同じ SPI transaction の CS を保持したまま 1 byte ずつ送信する。各 byte の完了後、ROM アドレスを 1 増加する。ページ境界をまたぐ動作は外部 SPI flash の page program 仕様に依存するため、ソフトウェアは 1 page 内に収まる単位で使用する。

### 5.5 `CHIP_ERASE` (`0x04`)

command port に `0x04` を write すると、data port を使用せずに次の操作を開始する。

```text
WRITE_ENABLE (0x06)
CHIP_ERASE (0x60)
```

コマンド処理中は `bus_ready` が Low となり、SPI transaction が完了してから High に戻る。消去処理自体の完了は外部 flash の status register の busy bit で確認する。

### 5.6 `READ_STATUS` (`0x05`)

data port を read すると、Serial ROM の status register 1 を読み出す。`bus_rdata[0]` に status register の busy bit（S0）が入り、その他の bit は現在の SPI status data を返す。

status register 1 の主な bit は次のとおり。

| bit | 名称 |
|---:|---|
| 0 | BUSY |
| 1 | Write Enable Latch |
| 2～4 | Block Protect |
| 5 | Top/Bottom Write Protect |
| 6 | Sector Protect |
| 7 | Status Register Protect |

### 5.7 `SELECT_SROM` (`0x06`)

data port に ROM 番号を書き込んで、接続先を選択する。

| data | `srom0_cs_n` | `srom1_cs_n` | 動作 |
|---:|---:|---:|---|
| `0x00` | Low | High | ROM #0 を選択 |
| `0x01` | High | Low | ROM #1 を選択 |
| `0x02`～`0xFE` | High | High | 未接続状態 |
| `0xFF` | High | High | 未接続状態 |

### 5.8 `ACCESS_END` (`0x07`)

SPI serial transfer が idle になるまで待機し、その後内部の SPI ROM CS を High に戻す。burst read／burst write の終了時に使用する。

### 5.9 `WRITE_ENABLE` (`0x08`)

外部 SPI flash へ `WRITE_ENABLE (0x06)` のみを発行する。erase や page program の前に、flash の write enable latch を設定する用途で使用する。

### 5.10 `BLOCK_ERASE` (`0x09`)

`SET_ADDRESS` で設定した 24 bit アドレスを使って、次の操作を実行する。

```text
WRITE_ENABLE (0x06)
BLOCK_ERASE (0xD8)
address[23:16], address[15:8], address[7:0]
```

### 5.11 `READ_STATUS_2` (`0x0A`)

data port を read すると status register 2（外部 SPI コマンド `0x35`）を読み出す。status register 2 の bit 0 が `bus_rdata[0]` に入る。

## 6. 内部動作

### 6.1 バス受付と完了

`bus_ready` は、外部 SPI transfer 中や CS 待ちが必要な command の処理中は Low となる。`bus_valid` が受理されると、コマンド FSM は必要な SPI byte を順番に発行する。

- command port の mode 設定は、通常 1 クロックで受理される。
- data port write／read は、対応する外部 SPI transaction 完了まで busy となる。
- `bus_rdata_en` は ROM read data または status data が有効になった時点で 1 クロックだけ High となる。
- `bus_ready` が Low の間、上位バスマスターは要求を保持して待機する。

### 6.2 コマンド FSM

| 状態 | 動作 |
|---|---|
| `ST_IDLE` | `ff_do_command` を待つ |
| `ST_READ_MODE` | fast read command などを外部 ROM へ送る |
| `ST_READ_ADDR_H/M/L` | 24 bit アドレスを上位 byte から送る |
| `ST_READ_DUMMY` | fast read の dummy byte を送る |
| `ST_READ_BYTE` | ROM から 1 byte 読み出す |
| `ST_RECEIVE_BYTE` | burst read の連続受信を行う |
| `ST_WRITE_MODE` | page program command を開始する |
| `ST_WRITE_ADDR_H/M/L` | page program のアドレスを送る |
| `ST_WRITE_BYTE` | write data byte を送る |
| `ST_ERASE` | chip erase command を送る |
| `ST_BLOCK_ERASE_ADDR_H/M/L` | block erase のアドレスを送る |
| `ST_WAIT` | write enable 完了など、次の command 開始を待つ |
| `ST_FINISH` | serial transfer idle を待ち、command を完了する |

SPI byte transfer は内部の serial controller により、write mode と read mode を切り替えて実行される。

### 6.3 CS 待ち時間

外部 ROM の CS 切り替え後に必要な待ち時間を内部カウンタで挿入する。read/status 系では短い待ち時間、通常の write／erase 系では長い待ち時間を使用する。実際の時間は `clk` 周波数と次の定数に依存する。

| 定数 | 値 | 用途 |
|---|---:|---|
| `CS_WAIT_10NS` | 1 | burst read、status read、status register 2 |
| `CS_WAIT_50NS` | 5 | その他の command |

### 6.4 データ方向制御

`srom_do`、`srom_di`、`srom_hold_n`、`srom_wp_n` は inout 端子である。read operation では ROM の data out を取り込み、write operation では ROM へ command、address、data を出力する。HOLD# と WP# は通常非使用状態として扱う。

## 7. 外部 SPI flash コマンド対応

| 内部 command | 外部 opcode | 説明 |
|---|---:|---|
| `SINGLE_READ`／`BURST_READ` | `0x0B` | Fast Read |
| `BURST_WRITE` | `0x06`, `0x02` | Write Enable、Page Program |
| `CHIP_ERASE` | `0x06`, `0x60` | Write Enable、Chip Erase |
| `READ_STATUS` | `0x05` | Status Register 1 |
| `WRITE_ENABLE` | `0x06` | Write Enable |
| `BLOCK_ERASE` | `0x06`, `0xD8` | Write Enable、Block Erase |
| `READ_STATUS_2` | `0x35` | Status Register 2 |

## 8. リセット後の状態

- command mode は `SET_ADDRESS`。
- ROM アドレスは 0。
- burst byte counter は 0。
- `bus_ready` は High。
- `bus_rdata_en` は Low。
- `srom0_cs_n` と `srom1_cs_n` はともに High。
- 外部 SPI CS は非選択状態。
- SPI serial transfer は idle。
