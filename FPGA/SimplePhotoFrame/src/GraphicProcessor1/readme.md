# GraphicProcessor1 仕様

## 1. 概要

`GraphicProcessor1` は、VRAM 上の矩形領域に対して RGB565 の矩形塗りつぶし、または論理演算を行うグラフィックプロセッサーである。画面サイズは 800 x 480 pixels、VRAM の水平ストライドは 1024 pixels とする。

主な動作は次のとおり。

1. レジスタへ描画位置、矩形サイズ、色、ROP、VRAM アドレスを設定する。
2. `EXEC` に 1 を書き込むと、設定値を実行用レジスタへ取り込み、処理を開始する。
3. 矩形が画面外にはみ出す場合は、画面内に入る部分だけをクリップする。負の座標にも対応する。
4. `PUT` 以外の ROP では、各画素を SDRAM から読み出し、演算結果を同じアドレスへ書き戻す。
5. 全画素の書き込みが完了すると `STATUS` を 0 に戻し、SDRAM の write-back cache に対して flush 要求を 1 回発行する。

処理中は `STATUS = 1` となり、次の `EXEC` は受け付けない。flush 要求が完了するまで、次の `EXEC` も受け付けない。

## 2. モジュールインターフェース

### クロック／リセット

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `clk` | input | 1 | システムクロック。レジスタおよび処理 FSM の基準クロック |
| `reset` | input | 1 | High active 同期リセット |
| `sdram_init_busy` | input | 1 | SDRAM 初期化中を示す信号。High の間はバス要求を停止 |

### レジスタバス

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `bus_cs` | input | 1 | 本モジュール選択 |
| `bus_address` | input | 5 | レジスタ番号 |
| `bus_valid` | input | 1 | バス要求有効 |
| `bus_ready` | output | 1 | 要求受付可能。`sdram_init_busy = 0` のとき High |
| `bus_write` | input | 1 | High: write、Low: read |
| `bus_wdata` | input | 16 | 書き込みデータ |
| `bus_rdata` | output | 16 | 読み出しデータ |
| `bus_rdata_valid` | output | 1 | 読み出しデータ有効 |

書き込みレジスタは `bus_cs && bus_valid && bus_write` が成立したクロックで更新される。`bus_ready` は SDRAM 初期化中だけ Low となる。読み出し要求を受けると、次のクロックで `bus_rdata_valid` を 1 クロックだけ出力する。

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

要求は `sdram_valid && sdram_ready` が成立したクロックで受理される。`sdram_valid = 1` かつ `sdram_flush = 0` の場合、`sdram_write` が 1 なら書き込み、0 なら読み出しである。flush は `sdram_valid = 1`、`sdram_flush = 1` として発行され、アドレスおよびデータは使用しない。

## 3. レジスタ表

| アドレス | 名称 | R/W | ビット | リセット値 | 概要 |
|---:|---|:---:|---|---|---|
| `0x00` | `SX` | R/W | `[15:0]` | `0` | 矩形左上の X 座標。signed 16 bit |
| `0x01` | `SY` | R/W | `[15:0]` | `0` | 矩形左上の Y 座標。signed 16 bit |
| `0x02` | `WIDTH` | R/W | `[15:0]` | `0` | 矩形幅 |
| `0x03` | `HEIGHT` | R/W | `[15:0]` | `0` | 矩形高さ |
| `0x04` | `COLOR` | R/W | `[15:0]` | `0` | 描画元の RGB565 色 |
| `0x05` | `ROP` | R/W | `[15:0]` | `0` | 描画論理演算の選択 |
| `0x06` | `EXEC` / `STATUS` | W / R | `[0]` | `0` | 実行開始／実行中状態 |
| `0x07` | `VRAM_ADDRESS_L` | R/W | `[15:0]` | `0` | VRAM アドレス bit `[16:1]` |
| `0x08` | `VRAM_ADDRESS_H` | R/W | `[5:0]` | `0` | VRAM アドレス bit `[22:17]` |
| `0x09`～`0x1F` | - | - | - | - | 未使用。読み出しは 0、書き込みは無視 |

## 4. 各レジスタの説明

### 4.1 `SX` (`0x00`)、`SY` (`0x01`)

矩形の左上座標を signed 16 bit で設定する。設定可能な数値範囲は -32768～32767 である。

画面外の負座標を指定した場合、描画開始位置は 0 にクリップされ、矩形の幅または高さから画面外部分を減算する。始点が画面サイズ以上の場合、該当方向のクリップ後サイズは 0 となる。

### 4.2 `WIDTH` (`0x02`)、`HEIGHT` (`0x03`)

矩形の幅と高さを unsigned 16 bit で設定する。指定範囲の終端は `SX + WIDTH`、`SY + HEIGHT` の直前であり、幅または高さが 0 の場合は何も描画しない。

画面境界を越える場合のクリップ後サイズは次の考え方で決まる。

```text
visible_left  = max(SX, 0)
visible_right = min(SX + WIDTH, 800)
visible_width = max(visible_right - visible_left, 0)

visible_top    = max(SY, 0)
visible_bottom = min(SY + HEIGHT, 480)
visible_height = max(visible_bottom - visible_top, 0)
```

### 4.3 `COLOR` (`0x04`)

ROP の source operand として使用する RGB565 色を設定する。

```text
COLOR[15:11] = R[4:0]
COLOR[10: 5] = G[5:0]
COLOR[ 4: 0] = B[4:0]
```

### 4.4 `ROP` (`0x05`)

画素ごとの演算を選択する。定義値は「7. ROP 演算」を参照する。未定義値は `PUT` と同じく `COLOR` を書き込む。

### 4.5 `EXEC` / `STATUS` (`0x06`)

write 時に `bus_wdata[0] = 1` で実行を開始する。開始条件は `!STATUS` かつ flush 待ちでないことである。開始時に `SX`、`SY`、`WIDTH`、`HEIGHT`、`COLOR`、`ROP`、`VRAM_ADDRESS` を実行用レジスタへコピーするため、実行中に設定レジスタを書き換えても現在の処理には影響しない。

read 時は `bus_rdata[0]` に STATUS を返す。

| STATUS | 状態 |
|---:|---|
| `0` | 待機中、または全画素の書き込み完了後。flush 要求の受付完了後に次の EXEC が可能 |
| `1` | 矩形処理中。SDRAM read、ROP、write、画素／行の更新を実行中 |

### 4.6 `VRAM_ADDRESS_L` (`0x07`)、`VRAM_ADDRESS_H` (`0x08`)

矩形の左上に対応する VRAM の 16 bit ワードアドレスを設定する。

```text
vram_address = { VRAM_ADDRESS_H[5:0], VRAM_ADDRESS_L[15:0] }
```

`VRAM_ADDRESS_L` が bit `[16:1]`、`VRAM_ADDRESS_H` が bit `[22:17]` を保持する。`VRAM_ADDRESS_H[15:6]` は無視される。

## 5. 内部動作

### 5.1 実行開始とクリップ

`EXEC` を受理すると、設定値を実行用レジスタへスナップショットし、`SX/SY/WIDTH/HEIGHT` から画面内の矩形を計算する。クリップ後の幅または高さが 0 の場合は SDRAM 要求を発行せず、STATUS を 0 に戻して終了する。

有効矩形がある場合、最初の画素アドレスを次式で計算し、現在アドレスと行先頭アドレスへ設定する。

```text
row_start_address = vram_address + clipped_sx + clipped_sy * 1024
cur_address       = row_start_address
```

### 5.2 FSM の状態遷移

内部処理は次の状態で構成される。

| 状態 | 動作 |
|---|---|
| `IDLE` | 実行要求を待つ |
| `ISSUE_READ` | `PUT` 以外で現在画素を SDRAM read 要求する |
| `WAIT_READ_DATA` | `sdram_rdata_valid` を待ち、既存画素を取り込む |
| `ISSUE_WRITE` | ROP 結果を現在画素へ SDRAM write 要求する |
| `NEXT_PIXEL` | X 方向、次に Y 方向へカウンタとアドレスを進める |
| `ISSUE_FLUSH` | 全画素完了後に flush 要求を発行する |

SDRAM の read と write はそれぞれ `sdram_valid && sdram_ready` の成立を待って次状態へ進む。read ではさらに `sdram_rdata_valid` を待ってから演算するため、SDRAM の応答レイテンシに依存せず処理できる。

### 5.3 PUT と read-modify-write

ROP が `PUT` の場合は既存画素を読み出さず、`COLOR` をそのまま書き込む。1 画素あたり 1 回の SDRAM write 要求となる。

ROP が `PUT` 以外の場合は、次の順序で 1 画素を処理する。

1. `cur_address` の既存画素を read 要求する。
2. `sdram_rdata_valid` で destination 色を取り込む。
3. `COLOR` を source、読み出した値を destination として ROP を計算する。
4. 演算結果を同じ `cur_address` へ write 要求する。
5. 次の画素へ進む。

### 5.4 画素・行の走査

X は左から右へ 0～`clipped_width - 1` の順で進む。1 行の末尾に到達すると X を 0 に戻し、Y を 1 増やす。次の行のアドレスは現在の行先頭アドレスに 1024 を加えて求める。

```text
next_pixel_address = cur_address + 1       (同一行)
next_row_address   = row_start_address + 1024
```

最終行の最終画素を書き込むと、STATUS を 0 にし、flush 待ちフラグを立てて `ISSUE_FLUSH` へ遷移する。

### 5.5 flush

矩形の書き込み完了後、`sdram_valid = 1`、`sdram_flush = 1`、`sdram_write = 0` の要求を発行する。`sdram_ready = 1` で受理されるまで要求を保持する。

flush 要求は、キャッシュ上の dirty データを SDRAM へ反映させるためのものであり、矩形処理の完了通知と SDRAM への反映完了を同期させる役割を持つ。flush 待ち中は STATUS は 0 だが、次の EXEC は受け付けない。

## 6. サイズと座標系

画面座標は左上を原点とする。

| 項目 | 値 |
|---|---:|
| 画面幅 | 800 pixels |
| 画面高さ | 480 pixels |
| 左上 | `(0, 0)` |
| 右下 | `(799, 479)` |
| VRAM 水平ストライド | 1024 pixels |
| 画素形式 | RGB565、16 bit |

`VRAM_ADDRESS` は矩形の論理座標 `(SX, SY)` に対応する基準アドレスである。画面内の画素 `(x, y)` に対応する SDRAM アドレスは次式となる。

```text
sdram_address = VRAM_ADDRESS + x + y * 1024
```

このアドレスは 16 bit pixel word 単位であり、RTL の `sdram_address[22:1]` に対応する。アドレス bit 0 はインターフェースに存在しないため、byte address として扱う場合は上式の値を 2 倍する。

## 7. ROP 演算

演算は RGB565 の各成分に対して行う。`src` は `COLOR`、`dst` は SDRAM から読み出した既存画素である。

| 値 | 名称 | 演算 |
|---:|---|---|
| `0x0000` | PUT | `src` をそのまま出力 |
| `0x0001` | OR | `dst OR src` |
| `0x0002` | AND | `dst AND src` |
| `0x0003` | XOR | `dst XOR src` |
| `0x0004` | ADD | R/G/B 成分ごとに加算。最大値で飽和 |
| `0x0005` | SUB | R/G/B 成分ごとに `dst - src`。0 で飽和 |
| `0x0006` | MIX | R/G/B 成分ごとに `(dst + src) >> 1` |
| `0x0007` | MIN | R/G/B 成分ごとの小さい方 |
| `0x0008` | MAX | R/G/B 成分の大きい方 |

ADD の飽和値は R/B が 31、G が 63 である。SUB は各成分が負にならないよう 0 で飽和する。MIX は各成分の加算結果を 1 bit 右シフトする。

## 8. リセット後の状態

- STATUS は 0。
- すべての描画パラメータは 0。
- ROP は `PUT`。
- VRAM アドレスは 0。
- SDRAM 要求は無効。
- SDRAM 初期化中はバス要求および SDRAM 要求を停止する。