# 概要
VRAM (SDRAM) への読み書きを行うモジュール

# 入出力
|ポート名|方向|ビット幅|説明|
|---|---|---|---|
|bus_cs|入力|1|チップセレクト|
|bus_address|入力|5|レジスタアドレス|
|bus_valid|入力|1|バス有効信号|
|bus_ready|出力|1|バス準備完了信号|
|bus_write|入力|1|書き込み信号|
|bus_wdata|入力|16|書き込みデータ|
|bus_rdata|出力|16|読み出しデータ|
|bus_rdata_valid|出力|1|読み出しデータ有効信号|

# レジスタ
|アドレス|名前|読み書き|説明|
|---|---|---|---|
|0x00|VRAM_ADDRESS_L|RW|VRAM アドレス[15:1], 16bitデータのうち 上位15bit のみ有効。最下位 1bit は read すると 0 |
|0x01|VRAM_ADDRESS_H|RW|VRAM アドレス[22:16] |
|0x02|VRAM_DATA|RW|VRAM データ|
|0x03|FLUSH|W|1を書き込むと、書き込みデータをフラッシュする|

VRAM_DATA は、書き込みまたは読み出しを行うたびに、VRAM_ADDRESS がインクリメントする。
FLUSH に1を書き込むと、VRAM_ADDRESS はインクリメントせずに、書き込みデータをフラッシュする。
