# SOFTWAREのビルド
SOFTWARE/build をカレントにして、WSL から make -j を実行することで行える。
RaspberryPiPico2W をターゲットとして、PicoSDK を使ったビルド環境を想定している。

# PCB
KiCad のプロジェクトファイルがそのまま置いてある

# CASE
基板と液晶パネルを固定するためのケースデータが STEPファイルで置いてある。

# FPGA
GOWIN EDA のプロジェクトファイルがそのまま置いてある。TangNano20K をターゲットとしている。

## RTL
Verilogによって記述。
フリップフロップ名は ff_ の接頭語をつける。
ワイヤー名は w_ の接頭語をつける。
output reg は使用禁止。
always @( * ) は使用禁止。
シミュレーションは、ModelSIM Starter Edition を使う。
