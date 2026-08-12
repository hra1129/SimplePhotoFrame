# DisplayController 仕様

## 1. 概要

`DisplayController` は、SDRAM に格納された RGB565 画像を読み出し、LCD パネルへ 800 x 480 pixels の映像として出力する表示コントローラである。

主な動作は次のとおり。

1. レジスタに設定された VRAM ベースアドレスから、表示 1 行分の画像データを読み出す。
2. SDRAM からは 32 bit ワードを 8 ワード単位のバーストで取得する。
3. 取得したデータを先読みバッファへ蓄積し、LCD の画素要求に合わせて 16 bit RGB565 として出力する。
4. `display_on = 1` のときは SDRAM の画像を表示し、`display_on = 0` のときは `fill_color` で画面全体を塗りつぶす。
5. `display_on` と VRAM ベースアドレスの表示側への反映は、表示途中で画面が乱れないようフレーム境界で行う。

表示を有効にした場合の SDRAM 要求アドレスは、次式で生成される。

```text
SDRAM burst address = base_address + (y * 64) + x_burst
x_burst = 0 .. 49    (1 行 800 pixels / 16 pixels per burst)
y       = 0 .. 479
```

VRAM の 1 行のストライドは 1024 pixels であり、表示幅 800 pixels の外側 224 pixels は読み出さない。上式のアドレスは `sdram_address[22:5]` で表すバーストアドレスである。1 アドレスの受理ごとに 32 bit ワード 8 個（RGB565 画素 16 個）を読み出す。

## 2. モジュールインターフェース

### クロック／リセット

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `clk` | input | 1 | システムクロック。レジスタ、SDRAM 要求、LCD タイミングの基準クロック |
| `reset` | input | 1 | High active 同期リセット |
| `sdram_init_busy` | input | 1 | SDRAM 初期化中を示す信号。High の間はレジスタバスを受け付けない |

### レジスタバス

| 信号 | 方向 | 幅 | 説明 |
|---|---:|---:|---|
| `bus_cs` | input | 1 | 本モジュール選択 |
| `bus_address` | input | 5 | レジスタ番号。下記レジスタ表を参照 |
| `bus_valid` | input | 1 | バス要求有効 |
| `bus_ready` | output | 1 | 要求受付可能 |
| `bus_write` | input | 1 | High: write、Low: read |
| `bus_wdata` | input | 16 | 書き込みデータ |
| `bus_rdata` | output | 16 | 読み出しデータ |
| `bus_rdata_valid` | output | 1 | 読み出しデータ有効 |

書き込みは `bus_cs && bus_valid && bus_ready && bus_write` が成立したクロックで確定する。未使用レジスタへの書き込みは無視される。読み出しはレジスタ 4 または 5 に対してのみ `bus_ready` を一時的に Low とし、`bus_rdata_valid` を出力する。

### LCD インターフェース

| 信号 | 幅 | 説明 |
|---|---:|---|
| `lcd_ck` | 1 | LCD pixel clock |
| `lcd_hs` | 1 | 水平同期。Low が同期期間 |
| `lcd_vs` | 1 | 垂直同期。Low が同期期間 |
| `lcd_de` | 1 | 有効表示期間。表示画素期間のみ High |
| `lcd_r` | 5 | RGB565 の R |
| `lcd_g` | 6 | RGB565 の G |
| `lcd_b` | 5 | RGB565 の B |
| `lcd_bl` | 1 | バックライト制御。RTL では常時 High |

## 3. レジスタ表

`bus_address` は 5 bit だが、現在定義されているレジスタは 0～5 である。

| アドレス | 名称 | R/W | ビット | リセット値 | 概要 |
|---:|---|:---:|---|---|---|
| `0x00` | `BASE_ADDRESS_L` | W | `[15:4]` | `0x0000` | VRAM ベースアドレス bit `[16:5]` |
| `0x01` | `BASE_ADDRESS_H` | W | `[5:0]` | `0x0000` | VRAM ベースアドレス bit `[22:17]` |
| `0x02` | `DISPLAY_ON` | W | `[0]` | `0` | 画像表示の有効／無効 |
| `0x03` | `SDRAM_INIT_BUSY` | R | `[0]` | - | `sdram_init_busy` の状態 |
| `0x04` | `FILL_COLOR` | W | `[15:0]` | `0xF800` | 表示 OFF 時の RGB565 塗りつぶし色 |
| `0x05` | `FRAME_END_WAIT` | R/W | `[0]` | `0` | フレーム境界待ち要求。フレーム終端で自動クリア |
| `0x06`～`0x1F` | - | - | - | - | 未使用。書き込みは無視 |

## 4. 各レジスタの説明

### 4.1 `BASE_ADDRESS_L` (`0x00`)

`bus_wdata[15:4]` を VRAM ベースアドレスの bit `[16:5]` に格納する。下位側 12 bit を設定するレジスタであり、`bus_wdata[3:0]` は無視される。

ベースアドレスを変更する場合は、先に `0x00`、続けて `0x01` の順で書き込む。表示に使用されるアドレスは、上位レジスタの書き込みを契機に新しい設定が有効になり、次のフレーム境界で表示アドレス生成器へ反映される。

### 4.2 `BASE_ADDRESS_H` (`0x01`)

`bus_wdata[5:0]` を VRAM ベースアドレスの bit `[22:17]` に格納する。`bus_wdata[15:6]` は無視される。

実効ベースアドレスは次の 18 bit 値である。

```text
base_address = { BASE_ADDRESS_H[5:0], BASE_ADDRESS_L[15:4] }
```

### 4.3 `DISPLAY_ON` (`0x02`)

`bus_wdata[0]` を表示モードとして格納する。

| 値 | 動作 |
|---:|---|
| `0` | SDRAM データを読まず、`FILL_COLOR` で表示 |
| `1` | SDRAM から画像データを読み出して表示 |

レジスタ値は即時に書き換わるが、LCD タイミング生成器へ渡す表示モードは `frame_end` で更新される。したがってフレーム途中で書き換えても、表示モードは次のフレーム境界まで維持される。リセット後は OFF である。

### 4.4 `SDRAM_INIT_BUSY` (`0x03`)

読み出し専用で、`bus_rdata[0]` に入力 `sdram_init_busy` を返す。High は SDRAM 初期化中、Low は初期化処理中でないことを示す。

レジスタコメントに「初期化完了フラグ」とあるが、実際の RTL の値は完了フラグの反転値ではなく、`sdram_init_busy` そのものである。初期化中は `bus_ready` も Low になる。

### 4.5 `FILL_COLOR` (`0x04`)

16 bit の RGB565 色を格納する。

```text
bus_wdata[15:11] = R[4:0]
bus_wdata[10: 5] = G[5:0]
bus_wdata[ 4: 0] = B[4:0]
```

`DISPLAY_ON = 0` のとき、内部の 32 bit データ経路には `{fill_color, fill_color}` として供給される。リセット値は `16'hF800`（赤）である。

### 4.6 `FRAME_END_WAIT` (`0x05`)

bit 0 に `1` を書き込むと、値をそのまま読み出せる状態フラグをセットする。`frame_end` が発生すると自動的に `0` へクリアされる。読み出し値は `bus_rdata[0]`、その他のビットは 0 である。

このフラグは表示アドレス生成器内部のフレーム境界同期と組み合わせて、ソフトウェアからフレーム境界を待つ用途に使用できる。書き込み時の `bus_wdata[0]` が 0 の場合はクリアされるが、フレーム終端が同時に発生した場合はフレーム終端によるクリアが優先される。

## 5. LCD タイミング

### 5.1 クロック

LCD の水平カウンタは `lcd_ck` の立ち上がりごとに 1 pixel 進む。`lcd_ck` は `clk` を 4 クロック単位で分周して生成されるため、RTL コメントに記載された 81 MHz のシステムクロックを前提にすると、pixel clock は 20.25 MHz となる。

画像データが先読みバッファにない場合、アクティブ表示期間の `lcd_ck` は停止する。これによりタイミングカウンタも停止し、画素データが用意されるまで画面位置を進めない。

### 5.2 水平タイミング

水平カウンタは 0～899 を 1 周期とする。1 line は合計 900 pixel clocks である。

| 区間 | カウンタ範囲 | 長さ | `lcd_hs` | `lcd_de` | 説明 |
|---|---:|---:|---:|---:|---|
| HSYNC | 0～19 | 20 | Low | Low | 水平同期パルス |
| Back porch | 20～24 | 5 | High | Low | 同期解除から表示開始まで |
| Active video | 25～824 | 800 | High | High | 有効な 800 pixel |
| Front porch | 825～899 | 75 | High | Low | 表示終了から次の同期まで |
| **合計** | **0～899** | **900** | - | - | 1 line |

`lcd_hs` は Low active で、同期パルス終了後に High となる。

### 5.3 垂直タイミング

垂直カウンタは 0～499 を 1 frame とする。1 frame は合計 500 lines である。

| 区間 | カウンタ範囲 | 長さ | `lcd_vs` | `lcd_de` | 説明 |
|---|---:|---:|---:|---:|---|
| VSYNC | 0～9 | 10 lines | Low | Low | 垂直同期パルス |
| Back porch | 10～14 | 5 lines | High | Low | 同期解除から表示開始まで |
| Active video | 15～494 | 480 lines | High | High* | 有効な 800 x 480 pixels |
| Front porch | 495～499 | 5 lines | High | Low | 表示終了から次の同期まで |
| **合計** | **0～499** | **500 lines** | - | - | 1 frame |

`lcd_vs` も Low active である。`lcd_de` は水平・垂直の active 条件が同時に成立したときだけ High となるため、表中の垂直 active 区間でも水平 porch 中は Low である。

### 5.4 画素データと `lcd_de`

`lcd_de = 1` の間、`p_data` の RGB565 値が次のように LCD 出力へ接続される。

```text
lcd_r = p_data[15:11]
lcd_g = p_data[10:5]
lcd_b = p_data[4:0]
```

`lcd_de = 0` の間は R/G/B 出力を 0 とする。`lcd_bl` は常時 High である。

内部画素バスは `p_valid/p_ready` のハンドシェイクである。`p_ready` はアクティブ表示領域の `lcd_ck` Low phase にだけ High となり、`p_valid = 0` のままの場合は `lcd_ck`、水平・垂直カウンタ、および同期信号の更新を停止する。

### 5.5 `frame_end`

`frame_end` は、最後の表示画素（水平カウンタ 824、垂直カウンタ 494）の `lcd_ck` 立ち上がりに 1 クロックだけ High となるパルスである。このパルスで次の処理が行われる。

- 先読み表示バッファをクリアする。
- `DISPLAY_ON` の設定を表示側へ反映する。
- 新しい VRAM ベースアドレスを設定済みの場合、そのアドレスを次フレームの先頭アドレスとして反映する。
- `FRAME_END_WAIT` を 0 に戻す。

## 6. リセット後の状態

- `DISPLAY_ON` は OFF。
- VRAM ベースアドレスは 0。
- `FILL_COLOR` は RGB565 の赤（`16'hF800`）。
- LCD タイミングカウンタは水平 0、垂直 0 から開始する。
- SDRAM 初期化中はバスアクセスを待機する。
