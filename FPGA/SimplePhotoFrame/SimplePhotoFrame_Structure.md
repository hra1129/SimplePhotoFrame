# RasPiPico2W
コントローラーとして利用する。
FPGA には、SPI で接続されている。

# SPI to Register BUS bridge
ここから、FPGA内部。
Pico から、SPI で受け取ったアクセス要求を、内部の Register BUS に変換して各デバイスに配る。

# DisplayController
液晶パネルに対する制御信号を生成するデバイス。
DRAMの所定のアドレスを所定の速度で読みだして、表示する。

# GraphicProcessor1
DRAMに対して、矩形塗りつぶしを行うプロセッサ。
座標とサイズと色を指定して実行する。
ロジカルオペレーションに対応。

# GraphicProcessor2
DRAMに対して、ブロック転送を行うプロセッサ。
座標とサイズを指定して実行する。
ロジカルオペレーションに対応。

# QSPI ROM Controller