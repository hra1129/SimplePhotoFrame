// -----------------------------------------------------------------------------
//	Gowin rPLL replacement models for simulation
//	These modules replace the Gowin FPGA hard macro PLLs with
//	simple clock generators for ModelSIM.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

// ====================================================================
//	Gowin_PLL: 132.00000MHz from 27.00000MHz
// ====================================================================
module Gowin_rPLL (
	output			clkout,
	output			clkoutp,
	input			clkin
);
	reg		r_clkout	= 1'b0;
	reg		r_clkoutp	= 1'b1;

	//	108.00000MHz
	always #(1_000_000_000.0 / 108_000_000.0 / 2.0) begin
		r_clkout	= ~r_clkout;
		r_clkoutp	= ~r_clkoutp;
	end

	assign clkout	= r_clkout;
	assign clkoutp	= r_clkoutp;
endmodule

module Gowin_rPLL2 (
	output			clkout,
	input			clkin
);
	reg		r_clkout	= 1'b0;

	//	216.00000MHz
	always #(1_000_000_000.0 / 216_000_000.0 / 2.0) begin
		r_clkout	= ~r_clkout;
	end

	assign clkout	= r_clkout;
endmodule
