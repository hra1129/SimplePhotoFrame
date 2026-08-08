`timescale 1ns/1ps

module tb;
	reg			clk;
	reg			reset;
	reg			clear;
	reg			display_on;
	reg	[15:0]	fill_color;
	reg	[22:5]	in_sdram_address;
	reg			in_sdram_address_valid;
	wire			in_sdram_address_ready;
	wire	[22:5]	sdram_address;
	wire			sdram_address_valid;
	reg			sdram_address_ready;
	reg	[31:0]	sdram_rdata;
	reg			sdram_rdata_valid;
	wire	[31:0]	out_data;
	wire			out_valid;
	reg			out_ready;

	integer			i;
	integer			valid_count;

	display_fillcolor_generator dut (
		.clk				( clk				),
		.reset				( reset				),
		.clear				( clear				),
		.display_on			( display_on			),
		.fill_color			( fill_color			),
		.in_sdram_address	( in_sdram_address	),
		.in_sdram_address_valid	( in_sdram_address_valid	),
		.in_sdram_address_ready	( in_sdram_address_ready	),
		.sdram_address		( sdram_address		),
		.sdram_address_valid	( sdram_address_valid	),
		.sdram_address_ready	( sdram_address_ready	),
		.sdram_rdata		( sdram_rdata		),
		.sdram_rdata_valid	( sdram_rdata_valid	),
		.out_data			( out_data			),
		.out_valid			( out_valid			),
		.out_ready			( out_ready			)
	);

	always #5 clk = ~clk;

	task automatic check_ok;
		input condition;
		input [255:0] message;
		begin
			if( !condition ) begin
				$display("[TB][ERROR] %0s", message);
				$finish(1);
			end
		end
	endtask

	task automatic issue_request;
		begin
			@(posedge clk);
			#1;
			check_ok(in_sdram_address_ready, "request_not_accepted");
			in_sdram_address_valid = 1'b1;
			@(posedge clk);
			#1;
			in_sdram_address_valid = 1'b0;
			if( display_on ) begin
				check_ok(sdram_address_valid == 1'b1, "sdram_address_valid_should_be_1_in_on_mode");
				check_ok(sdram_address == in_sdram_address, "sdram_address_should_passthrough");
			end
			else begin
				check_ok(sdram_address_valid == 1'b0, "sdram_address_valid_should_be_masked_in_off_mode");
			end
		end
	endtask

	initial begin
		clk = 1'b0;
		reset = 1'b1;
		clear = 1'b0;
		display_on = 1'b0;
		fill_color = 16'hA55A;
		in_sdram_address = 18'h12345;
		in_sdram_address_valid = 1'b0;
		sdram_address_ready = 1'b1;
		sdram_rdata = 32'd0;
		sdram_rdata_valid = 1'b0;
		out_ready = 1'b1;
		valid_count = 0;

		repeat(3) @(posedge clk);
		reset = 1'b0;

		// -------------------------------------------------------------
		// TEST1: display_on=0
		// 1request -> 8valid, data={fill_color,fill_color},
		// busy期間は in_sdram_address_ready=0、SDRAM要求はマスク
		// -------------------------------------------------------------
		display_on = 1'b0;
		fill_color = 16'h5AA5;
		in_sdram_address = 18'h2AA55;
		issue_request();

		valid_count = 0;
		for( i = 0; i < 8; i = i + 1 ) begin
			@(posedge clk);
			check_ok(in_sdram_address_ready == 1'b0, "request_ready_should_be_0_while_busy_off");
			check_ok(sdram_address_valid == 1'b0, "sdram_address_valid_should_be_masked_in_off_mode");
			check_ok(out_valid == 1'b1, "out_valid_should_be_1_in_off_mode");
			check_ok(out_data == {fill_color, fill_color}, "out_data_not_fill_color_pair");
			valid_count = valid_count + 1;
		end
		check_ok(valid_count == 8, "off_mode_valid_count_not_8");

		@(posedge clk);
		check_ok(in_sdram_address_ready == 1'b1, "request_ready_not_recovered_after_off_mode");
		check_ok(out_valid == 1'b0, "out_valid_should_drop_after_off_mode_8beats");

		// -------------------------------------------------------------
		// TEST2: display_on=1
		// SDRAMアドレス要求はそのまま通し、
		// sdram_rdata_valid を out_valid に反映する
		// -------------------------------------------------------------
		display_on = 1'b1;
		in_sdram_address = 18'h355AA;
		issue_request();

		@(posedge clk);
		#1;
		sdram_rdata_valid = 1'b1;
		sdram_rdata = 32'h1234_5678;

		valid_count = 0;
		i = 0;
		while( (valid_count < 8) && (i < 64) ) begin
			@(posedge clk);
			if( out_valid ) begin
				check_ok(out_data == 32'h1234_5678, "out_data_should_follow_sdram_data");
				if( valid_count < 7 ) begin
					check_ok(in_sdram_address_ready == 1'b0, "request_ready_should_be_0_while_busy_on");
				end
				valid_count = valid_count + 1;
			end
			i = i + 1;
		end
		check_ok(valid_count == 8, "on_mode_valid_count_not_8");

		// 8valid完了後の次サイクルでready復帰
		@(posedge clk);
		#1;
		sdram_rdata_valid = 1'b0;
		@(posedge clk);
		#1;
		check_ok(in_sdram_address_ready == 1'b1, "request_ready_not_recovered_after_on_mode");
		check_ok(out_valid == 1'b0, "out_valid_should_drop_after_on_mode_8beats");

		// -------------------------------------------------------------
		// TEST3: SDRAM read burst中のframe clear
		// clear後に残りの旧frame dataが到着しても出力しない
		// -------------------------------------------------------------
		display_on = 1'b1;
		in_sdram_address = 18'h01234;
		issue_request();

		@(posedge clk);
		#1;
		sdram_rdata_valid = 1'b1;
		sdram_rdata = 32'hDEAD_BEEF;
		repeat(2) begin
			@(posedge clk);
			#1;
			check_ok(out_valid == 1'b1, "old_frame_data_missing_before_clear");
		end

		clear = 1'b1;
		@(posedge clk);
		#1;
		clear = 1'b0;
		check_ok(out_valid == 1'b0, "old_frame_data_visible_after_clear");
		check_ok(in_sdram_address_ready == 1'b1, "request_ready_not_recovered_after_clear");
		repeat(6) begin
			@(posedge clk);
			#1;
			check_ok(out_valid == 1'b0, "remaining_old_frame_data_visible_after_clear");
		end
		sdram_rdata_valid = 1'b0;

		$display("[TB] PASS display_fillcolor_generator behavior verified.");
		$finish;
	end
endmodule
