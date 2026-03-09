/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_TscherterJunior_top (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // input wires renamed
  wire [7:0] data_i;

  // output wires renamed
  wire read_en_o;
  wire instr_en_o;
  wire [7:0] addr_o;
  wire [7:0] data_o;


  //regs
  reg [7:0] reg0;
  reg [7:0] reg1;
  reg [7:0] reg2;
  reg [7:0] reg3;
  reg [7:0] reg4;
  reg [7:0] reg5;
  reg [7:0] reg6;
  reg [7:0] reg7;

  tt_um_TscherterJunior_ALU ALU_test (
    .opcode_i(4'b0010),

    .acc_i(ui_in),    
    .operand_i(uio_in), 

    .acc_o(uo_out),  
    .flags_o(data_o[1:0])
  );

  /*
  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  */
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule
