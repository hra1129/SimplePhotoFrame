# VramAccessor 仕様

## 1. 概要

`VramAccessor` は、内部レジスタバスから VRAM（SDRAM）上の 16 bit pixel word を単発で読み書きするためのアクセサリモジュールである。VRAM アドレスを保持し、`VRAM_DATA` の read／write が受理されるたびにアドレスを 1 word 自動インクリメントする。

主な動作は次のとおり。

1. VRAM アドレスを `VRAM_ADDRESS_L/H` に設定する。
2. `VRAM_DATA` write で指定アドレスへ 16 bit データを書き込む。
3. `VRAM_DATA` read で指定アドレスから 16 bit データを読み出す。
4. 通常の read／write の受理後は VRAM アドレスを 1 増やす。
5. `FLUSH` に 1 を書き込むと、現在のアドレスを変更せずに write-back cache の flush 要求を発行する。

同時に処理できる SDRAM 要求は 1 件である。要求中または read 応答待ちの間は `bus_ready` を Low にして、次のバスアクセスを受け付けない。

## 2. モジュールインターフェース

### クロック／リセット

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `clk` | input | 1 | システムクロック。レジスタと SDRAM 要求の基準クロック |
| `reset` | input | 1 | High active 同期リセット |
| `sdram_init_busy` | input | 1 | SDRAM 初期化中を示す信号。High の間はバス／要求を停止 |

### レジスタバス

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `bus_cs` | input | 1 | 本モジュール選択 |
| `bus_address` | input | 5 | レジスタ番号 |
| `bus_valid` | input | 1 | バス要求有効 |
| `bus_ready` | output | 1 | 要求受付可能 |
| `bus_write` | input | 1 | High: write、Low: read |
| `bus_wdata` | input | 16 | 書き込みデータ |
| `bus_rdata` | output | 16 | 読み出しデータ |
| `bus_rdata_valid` | output | 1 | 読み出しデータ有効 |

バス要求は `bus_cs && bus_valid && bus_ready` が成立したクロックで受理される。レジスタ read の応答は通常 1 クロックの `bus_rdata_valid` パルスで返る。`VRAM_DATA` read では SDRAM の read 応答を受信した時点で `bus_rdata_valid` を出力する。

### SDRAM インターフェース

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `sdram_address` | output | 22 | 16 bit VRAM ワードアドレス `[22:1]` |
| `sdram_write` | output | 1 | High: 書き込み、Low: 読み出し |
| `sdram_wdata` | output | 16 | 書き込みデータ |
| `sdram_valid` | output | 1 | SDRAM 要求有効 |
| `sdram_flush` | output | 1 | write-back cache の flush 要求 |
| `sdram_ready` | input | 1 | SDRAM 要求受付可能 |
| `sdram_rdata` | input | 16 | 読み出しデータ |
| `sdram_rdata_valid` | input | 1 | 読み出しデータ有効 |

`sdram_valid && sdram_ready` が成立したクロックで SDRAM 要求を受理する。`sdram_flush = 0` かつ `sdram_write = 1` は write、`sdram_write = 0` は read である。flush は `sdram_valid = 1`、`sdram_flush = 1` として発行される。

## 3. レジスタ表

| アドレス | 名称 | R/W | ビット | リセット値 | 概要 |
|---:|---|:---:|---|---|---|
| `0x00` | `VRAM_ADDRESS_L` | R/W | `[15:0]` | `0` | VRAM アドレス bit `[16:1]` |
| `0x01` | `VRAM_ADDRESS_H` | R/W | `[5:0]` | `0` | VRAM アドレス bit `[22:17]` |
| `0x02` | `VRAM_DATA` | R/W | `[15:0]` | `0` | VRAM の 16 bit pixel word |
| `0x03` | `FLUSH` | W | `[0]` | - | write-back cache の flush 要求 |
| `0x04`～`0x1F` | - | - | - | - | 未使用。読み出しは 0、書き込みは無視 |

## 4. 各レジスタの説明

### 4.1 `VRAM_ADDRESS_L` (`0x00`)

`bus_wdata[15:0]` を VRAM アドレスの bit `[16:1]` に格納する。`VRAM_ADDRESS_H` と組み合わせて 22 bit の 16 bit word address を構成する。

### 4.2 `VRAM_ADDRESS_H` (`0x01`)

`bus_wdata[5:0]` を VRAM アドレスの bit `[22:17]` に格納する。`bus_wdata[15:6]` は無視される。

実効アドレスは次式である。

```text
vram_address = { VRAM_ADDRESS_H[5:0], VRAM_ADDRESS_L[15:0] }
```

アドレスを更新する場合は、下位レジスタを書き込んだ後に上位レジスタを書き込む。`VRAM_DATA` または通常 read の SDRAM 要求が受理された後、内部アドレスは 1 word 増加する。

### 4.3 `VRAM_DATA` (`0x02`)

#### Write

`bus_wdata` を現在の `vram_address` へ SDRAM write 要求として発行する。要求が `sdram_ready` で受理された後、VRAM アドレスを 1 増加する。

#### Read

現在の `vram_address` の SDRAM read 要求を発行する。要求受理後に `sdram_rdata_valid` を待ち、受信した値を `bus_rdata` として `bus_rdata_valid` と同時に返す。read 要求の受理時点で VRAM アドレスは 1 増加するため、応答待ち中に次のアクセスは受け付けない。

### 4.4 `FLUSH` (`0x03`)

`bus_wdata[0] = 1` のとき、現在の VRAM アドレスを保持したまま flush 要求を発行する。flush では `sdram_write = 0`、`sdram_wdata` および `sdram_address` はデータ転送用途には使用しない。

flush 要求の受理後に `sdram_valid` と `sdram_flush` は Low へ戻り、VRAM アドレスはインクリメントされない。`bus_wdata[0] = 0` の書き込みは何も行わない。

## 5. 内部動作

### 5.1 バス受付制御

内部には SDRAM 要求保持フラグと read 応答待ちフラグがある。次の条件をすべて満たすときだけ `bus_ready` が High になる。

```text
bus_ready = !sdram_init_busy && !sdram_request_pending && !read_response_pending
```

したがって、`sdram_ready = 0` の期間に発行した要求は保持され、要求が受理されるまで新しいバス要求を受け付けない。read では SDRAM 要求が受理された後も `sdram_rdata_valid` を待つため、その間もバスは停止する。

### 5.2 Write の処理

1. `VRAM_DATA` write をバスで受理する。
2. 現在の VRAM アドレス、write 属性、`bus_wdata` を SDRAM 要求レジスタへラッチする。
3. `sdram_valid = 1` を保持し、`sdram_ready = 1` を待つ。
4. 要求受理時に `sdram_valid` を解除し、VRAM アドレスを 1 増加する。
5. 次のバスアクセスを受け付け可能にする。

`sdram_ready` が Low の場合、アドレス、データ、write 属性、valid は受理まで保持される。

### 5.3 Read の処理

1. `VRAM_DATA` read をバスで受理する。
2. 現在の VRAM アドレスを read 要求としてラッチする。
3. `sdram_valid = 1`、`sdram_write = 0` で `sdram_ready` を待つ。
4. 要求受理時に VRAM アドレスを 1 増加し、read 応答待ちへ移る。
5. `sdram_rdata_valid` を受信したらデータを保持し、`bus_rdata_valid` を 1 クロック出力する。
6. 応答待ちフラグを解除し、次のバスアクセスを受け付ける。

### 5.4 アドレス自動更新

通常の `VRAM_DATA` read／write は、SDRAM 要求の受理を条件にアドレスを増加する。従って `sdram_ready = 0` の間にアドレスが先行して変化することはない。

```text
next_address = current_address + 1
```

22 bit の範囲を越えた場合は、レジスタ幅に従って上位から循環する。`VRAM_ADDRESS_L/H` の直接書き込みと同時に `VRAM_DATA` 要求を発行することはなく、バスアクセスは直列化される。

### 5.5 flush の処理

`FLUSH` write を受理すると、現在アドレスを保持したまま `sdram_flush = 1` の要求を発行する。`sdram_ready` が Low の間は要求を保持し、受理されたクロックで要求を解除する。flush は通常 read／write ではないため、アドレス自動更新も read 応答待ちも発生しない。

## 6. アドレスとデータ形式

| 項目 | 値 |
|---|---:|
| VRAM アドレス幅 | 22 bit、`[22:1]` |
| アドレス単位 | 16 bit pixel word |
| 1 pixel | 16 bit |
| RGB 形式 | RGB565 |
| 水平ストライド | 1024 pixels |

画面座標 `(x, y)` の VRAM word address は、基準アドレスを `base_address` とすると次式で求める。

```text
address = base_address + x + y * 1024
```

RGB565 の各成分は次の配置である。

```text
[15:11] R[4:0]
[10: 5] G[5:0]
[ 4: 0] B[4:0]
```

このモジュールの SDRAM アドレスは pixel word address である。byte address として扱う場合は値を 2 倍する。

## 7. 典型的なアクセスシーケンス

### 7.1 連続 write

```text
write VRAM_ADDRESS_L
write VRAM_ADDRESS_H
write VRAM_DATA  -> address A     (A を A + 1 へ更新)
write VRAM_DATA  -> address A+1   (A+1 を A + 2 へ更新)
write FLUSH      -> address は保持
```

### 7.2 連続 read

```text
write VRAM_ADDRESS_L
write VRAM_ADDRESS_H
read  VRAM_DATA   -> address A の応答、次回アドレスは A + 1
read  VRAM_DATA   -> address A+1 の応答、次回アドレスは A + 2
```

read の発行後は `bus_rdata_valid` が出るまで次のアクセスを発行できない。

## 8. リセット後の状態

- VRAM アドレスは 0。
- 保持データは 0。
- SDRAM 要求は無効。
- read 応答待ちは解除。
- `sdram_init_busy = 1` の間はバス要求と SDRAM 要求を停止する。
