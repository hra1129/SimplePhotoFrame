# GraphicProcessor2 仕様

## 1. 概要

`GraphicProcessor2` は、VRAM 上の矩形画像を別の VRAM 領域へコピーするグラフィックプロセッサーである。コピー元とコピー先に異なる矩形サイズを指定でき、最近傍方式の拡大縮小を行う。画面サイズは 800 x 480 pixels、VRAM の水平ストライドは 1024 pixels とする。

主な動作は次のとおり。

1. コピー元／コピー先の座標、矩形サイズ、ROP、VRAM 基準アドレスを設定する。
2. `EXEC` に 1 を書き込むと設定値を実行用レジスタへ取り込み、処理を開始する。
3. コピー元とコピー先の各画素が画面内かを判定し、画面内の destination だけへアクセスする。
4. 出力矩形の各画素に対応する入力画素を、加算カウンタによるスケール計算で選択する。
5. ROP に応じて source 色と destination 色を組み合わせ、destination VRAM へ書き込む。
6. 全画素の書き込み後、SDRAM の write-back cache に対して flush 要求を 1 回発行する。

処理中は `STATUS = 1` となり、処理中または flush 待ちの間は次の `EXEC` を受け付けない。

## 2. モジュールインターフェース

### クロック／リセット

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `clk` | input | 1 | システムクロック。レジスタおよび処理 FSM の基準クロック |
| `reset` | input | 1 | High active 同期リセット |
| `sdram_init_busy` | input | 1 | SDRAM 初期化中を示す信号。High の間は処理とバス要求を停止 |

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

書き込みは `bus_cs && bus_valid && bus_write` が成立したクロックで更新される。読み出し要求を受けると `bus_rdata_valid` が 1 クロックだけ High となる。SDRAM 初期化中は `bus_ready` が Low となる。

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

`sdram_valid && sdram_ready` が成立したクロックで要求を受理する。`sdram_flush = 0` のとき、`sdram_write = 1` は書き込み、0 は読み出しである。flush は `sdram_valid = 1`、`sdram_flush = 1` で発行され、アドレスとデータは使用しない。

## 3. レジスタ表

| アドレス | 名称 | R/W | ビット | リセット値 | 概要 |
|---:|---|:---:|---|---|---|
| `0x00` | `SX` | R/W | `[15:0]` | `0` | コピー元左上 X。signed 16 bit |
| `0x01` | `SY` | R/W | `[15:0]` | `0` | コピー元左上 Y。signed 16 bit |
| `0x02` | `SWIDTH` | R/W | `[15:0]` | `0` | コピー元幅 |
| `0x03` | `SHEIGHT` | R/W | `[15:0]` | `0` | コピー元高さ |
| `0x04` | `DX` | R/W | `[15:0]` | `0` | コピー先左上 X。signed 16 bit |
| `0x05` | `DY` | R/W | `[15:0]` | `0` | コピー先左上 Y。signed 16 bit |
| `0x06` | `DWIDTH` | R/W | `[15:0]` | `0` | コピー先幅 |
| `0x07` | `DHEIGHT` | R/W | `[15:0]` | `0` | コピー先高さ |
| `0x08` | `ROP` | R/W | `[15:0]` | `0` | コピー時の論理演算 |
| `0x09` | `EXEC` / `STATUS` | W / R | `[0]` | `0` | 実行開始／実行中状態 |
| `0x0A` | `VRAM_SADDRESS_L` | R/W | `[15:0]` | `0` | コピー元アドレス bit `[16:1]` |
| `0x0B` | `VRAM_SADDRESS_H` | R/W | `[5:0]` | `0` | コピー元アドレス bit `[22:17]` |
| `0x0C` | `VRAM_DADDRESS_L` | R/W | `[15:0]` | `0` | コピー先アドレス bit `[16:1]` |
| `0x0D` | `VRAM_DADDRESS_H` | R/W | `[5:0]` | `0` | コピー先アドレス bit `[22:17]` |
| `0x0E`～`0x1F` | - | - | - | - | 未使用。読み出しは 0、書き込みは無視 |

## 4. 各レジスタの説明

### 4.1 `SX`／`SY`、`SWIDTH`／`SHEIGHT`

`SX` と `SY` はコピー元矩形の左上座標、`SWIDTH` と `SHEIGHT` はコピー元の幅と高さである。座標は signed 16 bit、サイズは unsigned 16 bit で扱う。

### 4.2 `DX`／`DY`、`DWIDTH`／`DHEIGHT`

`DX` と `DY` はコピー先矩形の左上座標、`DWIDTH` と `DHEIGHT` はコピー先の幅と高さである。出力画素は `(DX, DY)` から右方向・下方向へ走査する。

コピー元またはコピー先の座標が画面外の場合、各画素の可視判定により SDRAM read／write の扱いが変わる。destination が画面外の画素では write を行わず、source が画面外の画素は黒色として扱う。コピー元またはコピー先の幅・高さが 0 の場合は画素アクセスを行わず flush のみ発行する。

### 4.3 `ROP` (`0x08`)

source 色と destination 色の組み合わせ方法を選択する。定義値は「7. ROP 演算」を参照する。`PUT` では source 読み出し後に source 色をそのまま書き込む。未定義値は source 色を出力する。

### 4.4 `EXEC`／`STATUS` (`0x09`)

write 時に `bus_wdata[0] = 1` で実行を開始する。開始時に全座標、サイズ、ROP、source／destination VRAM アドレスを実行用レジスタへコピーするため、実行中の設定レジスタ変更は現在の処理に影響しない。

read 時は `bus_rdata[0]` に STATUS を返す。

| STATUS | 状態 |
|---:|---|
| `0` | 待機中、または最終書き込み後。flush 受付完了後に次の EXEC が可能 |
| `1` | 拡大縮小コピー、または SDRAM read／write 処理中 |

### 4.5 VRAM アドレスレジスタ

source と destination の基準アドレスは、それぞれ下位レジスタを先に、上位レジスタを後に書き込む。

```text
src_base_address = { VRAM_SADDRESS_H[5:0], VRAM_SADDRESS_L[15:0] }
dst_base_address = { VRAM_DADDRESS_H[5:0], VRAM_DADDRESS_L[15:0] }
```

各アドレスは 16 bit pixel word 単位であり、アドレス bit 0 は存在しない。上位レジスタの `[15:6]` は無視される。

## 5. 内部動作

### 5.1 実行開始と準備

`EXEC` を受理すると、コピー元／コピー先のサイズ関係から X 方向と Y 方向の拡大・縮小モードを判定する。拡大縮小の比率は、乗算器・除算器・剰余器を使わず、Bresenham 型の加算誤差カウンタで計算する。

縮小時は事前準備状態で `source_size / destination_size` の整数部分と余りに相当する step 値を加算反復で求める。実行中は、出力画素を 1 つ進めるたびに step と誤差を更新し、必要なときだけ source offset を 1 増やす。拡大時も同じ誤差蓄積により、一つの source pixel を複数の destination pixel に対応させる。

### 5.2 座標とアドレス

現在の destination 座標を `(cur_dx, cur_dy)`、source offset を `(src_x_offset, src_y_offset)` とすると、アクセスアドレスは次式で生成される。

```text
src_address = src_base + (SX + src_x_offset) + (SY + src_y_offset) * 1024
dst_address = dst_base + (DX + cur_dx)       + (DY + cur_dy)       * 1024
```

source と destination の座標が画面内かを個別に判定する。destination が画面外の場合は write を行わず、source が画面外の場合は source 色を `16'h0000` として扱う。ただし destination が有効な場合、ROP による destination read が必要なら read-modify-write を継続する。

### 5.3 FSM の状態遷移

| 状態 | 動作 |
|---|---|
| `IDLE` | EXEC を待つ |
| `PREPARE` | 座標、サイズ、アドレス、スケール誤差を初期化 |
| `PREPARE_X_DIV` | X 方向縮小時の step を加算反復で準備 |
| `PREPARE_Y_DIV` | Y 方向縮小時の step を加算反復で準備 |
| `ISSUE_SRC_READ` | source 座標と可視状態を計算 |
| `ISSUE_SRC_DECIDE` | source 再利用、source read、destination read、write を選択 |
| `ISSUE_SRC_REQ` | source pixel の SDRAM read 要求を発行 |
| `WAIT_SRC_READ` | source の `sdram_rdata_valid` を待つ |
| `ISSUE_DST_READ` | ROP 用 destination の SDRAM read 要求を発行 |
| `WAIT_DST_READ` | destination の read 応答を待つ |
| `ISSUE_WRITE` | ROP 結果を destination へ書き込む |
| `ISSUE_FLUSH` | 全出力画素完了後に flush を発行 |

各 SDRAM read／write は `sdram_valid && sdram_ready` が成立するまで要求を保持する。read 受理後は `sdram_rdata_valid` を待って次の処理へ進む。

### 5.4 source pixel の再利用

拡大時など、隣接する destination pixel が同じ source pixel を参照する場合がある。直前に読み出した source アドレスと現在の source アドレスが一致すると、SDRAM read を省略して保持済みの source 色を再利用する。これにより拡大時の同一画素の重複 read を削減する。

### 5.5 ROP と書き込み

`PUT` 以外では source read と destination read を行い、演算結果を destination へ書く。`PUT` は source 色をそのまま出力するため destination read は不要だが、画面外 source は黒として扱われる。

destination が画面外の画素では write を発行せず、スケールカウンタと destination 走査だけを進める。

### 5.6 走査と flush

X 方向を最後まで処理すると destination X を 0 に戻し、Y と source Y の誤差状態を更新して次の行へ進む。最終 destination pixel の書き込みが受理されると STATUS を 0 にし、flush 待ち状態へ移る。

flush は `sdram_valid = 1`、`sdram_flush = 1` として発行され、`sdram_ready = 1` で受理されるまで保持される。flush 待ち中は STATUS は 0 だが、次の EXEC は受け付けない。

## 6. サイズと座標系

| 項目 | 値 |
|---|---:|
| 画面幅 | 800 pixels |
| 画面高さ | 480 pixels |
| 左上 | `(0, 0)` |
| 右下 | `(799, 479)` |
| VRAM 水平ストライド | 1024 pixels |
| 画素形式 | RGB565、16 bit |

画素 `(x, y)` の VRAM word address は次式である。

```text
address = base_address + x + y * 1024
```

この値は 16 bit pixel word 単位で、RTL の `sdram_address[22:1]` に対応する。byte address として扱う場合は 2 倍する。

## 7. ROP 演算

`src` はコピー元画素、`dst` はコピー先から読み出した画素である。演算は RGB565 の各成分に対して行う。

| 値 | 名称 | 演算 |
|---:|---|---|
| `0x0000` | PUT | `src` をそのまま出力 |
| `0x0001` | OR | `dst OR src` |
| `0x0002` | AND | `dst AND src` |
| `0x0003` | XOR | `dst XOR src` |
| `0x0004` | ADD | 成分ごとに加算し、R/B は 31、G は 63 で飽和 |
| `0x0005` | SUB | 成分ごとに `dst - src`。0 で飽和 |
| `0x0006` | MIX | 成分ごとに `(dst + src) >> 1` |
| `0x0007` | MIN | 成分ごとの小さい方 |
| `0x0008` | MAX | 成分ごとの大きい方 |

## 8. リセット後の状態

- STATUS は 0。
- すべてのコピー元／コピー先座標とサイズは 0。
- ROP は `PUT`。
- source／destination VRAM 基準アドレスは 0。
- SDRAM 要求は無効。
- SDRAM 初期化中は処理とバス要求を停止する。
