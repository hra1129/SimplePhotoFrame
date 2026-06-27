# 概要
	bus arbiter は、４つのバスアクセス要求を受け、これをアービトレーションし、1つに絞るモジュールである。

# バスアクセス仕様
	input	[22:1]		busX_address,
	input				busX_write,
	input	[15:0]		busX_wdata,
	input				busX_valid,
	output				busX_ready,
	output	[15:0]		busX_rdata,
	output				busX_rdata_valid,

	address, write, wdata を確定させ、valid = 1 にすることで、バスアクセス要求をする。
	write = 1 の場合は、書き込みアクセスであり、wdata に書き込みデータをセットしておく。
	write = 0 の場合は、読み込みアクセスであり、rdata に読み込みデータが返ってくる。
	rdata は、rdata_valid = 1 のタイミングに有効である。

	ready は、要求を受ける側が「要求を受け付けられるタイミング」で 1 になる。
	valid = 1 は、ready = 1 のタイミングが来るまで valid = 1 を維持しなければならない。
	address, write, wdata も、valid = 1 にしたタイミング ready = 1 が来るまで、変更してはならない。

# アービトレーション仕様
	内部に、ff_priority レジスタを持っており、これは 2bit の値を持つ。
	この値は、最優先のバス番号(X)を示す。
	ready = 1 のときに、valid が１つしか来ていない場合は、その valid を通し、その valid に対応するバス番号 + 1 を ff_priority にセットする。
	valid が複数来ている場合は、{ bus3_valid, bus2_valid, bus1_valid, bus0_valid } の 4bit を、ff_priority の数だけ
	右ローテイトして、一番若いビット番号にある 1 になっている valid を採用する。
	ビット番号は、0,1,2,3 の 4通りあるが、一番若いビット番号にある 1 になってる ビット番号 + ff_priority の値 が、バス番号に対応している。
	valid が通過するたびに、採用した valid のバス番号 + 1 を ff_priority にセットすることにより、ラウンドロビンのプライオリティ設定を行う。

	write は、パイプライン処理で posted 動作になるため、ready = 1 の次のサイクルも、ready = 1 のままになる。
	read は、rdata_valid が返ってくるまで ready = 0 に落として、次の valid を受け付けない。