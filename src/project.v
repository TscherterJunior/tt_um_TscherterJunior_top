/*
 * Copyright (c) 2026 Nicolas Tscherter
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

  // we use the bidirectional pins for output only...
  uio_oe = 1'b1;

  // input wires renamed
  wire [7:0] data_i;
  assign data_i <= ui_in;

  // output wires renamed
  reg write_en_o;
  reg instr_en_o;

  assign uo_out[0] <= write_en_o;
  assign uo_out[1] <= instr_en_o;


  // FSM -------------------------------------------------------
  reg [2:0] state_q, state_d;

  // States:  000 - Fetch
  //          001 - Load  
  //          010 - Store Address
  //          011 - Store Data
  //          100 - Jump  Address
  //          101 - Jump  Data

  // Next State Comb
  always @(*) begin

      // Default state
      state_d =  3'b000

      case state_q
        3'b000: case opcode
            4'b1010 : state_d = 3'b001; // Load 
            4'b1011 : state_d = 3'b010;
            4'b0110 : begin
              if(instr[3])  state_d = 3'b100;
              else          state_d = 3'b000;
            end
        endcase
        3'b001: state_d = 3'b000;
        3'b010: state_d = 3'b011;
        3'b011: state_d = 3'b000;
        3'b100: state_d = 3'b101;
        3'b101: state_d = 3'b000;
      endcase
  end

  // Assign FF
  always @(posedge clk, rst_n) begin
      if(! rst_n) state_q <= 3'b000;
      else        state_q <= state_d;
  end

  // Output gen:
  always @(*) begin
      
      // defaults
      instr_en_o = 1'b0;
      write_en_o = 1'b0;

      case state_q
        3'b000: begin 
          instr_en_o = 1'b1;
        end
        3'b001: begin

        end
        3'b010: begin
          write_en_o = 1'b1;
        end
        3'b011: begin
          write_en_o = 1'b1;
        end
        3'b100 begin // Jump  Address
          write_en_o = 1'b1;
        end
        3'b101 begin // Jump  Data
          write_en_o = 1'b1;
        end
      endcase
  end

  // END FSM ---------------------------------------------------


  // Data Path -------------------------------------------------


  reg [7:0] inst_ptr;
  reg [7:0] instruction_q, instruction_d;
  wire [3:0] opcode;

  assign opcode <= instr[7:4];

  //regs
  reg [7:0] reg0;
  reg [7:0] reg1;
  reg [7:0] reg2;
  reg [7:0] reg3;
  reg [7:0] reg4;
  reg [7:0] reg5;
  reg [7:0] reg6;
  reg [7:0] reg7;

  reg [1:0] flags_q, flags_d;

  reg [7:0] regval;
  reg [7:0] accval;

  reg [7:0] newval;

  reg [7:0] memdata_out;

  // comb
  always @(*) begin

    // sane defaults
    accval = 8'b0000_0000;
    regval = 8'b0000_0000;
    address = inst_ptr + 8'b1;
    uio_out = address;
    newval = 8'b0000_0000;
    flags_d = flags_q;

    // set accumulator value based instruction
    if(instr[3])  accumulator = reg1;
    else          accumulator = reg0;

    // set regval based on instruction
    if(instr[7:5] == 0'b000) begin
        case instr[2:0]

          3'b000: regval = reg0;
          3'b001: regval = reg1;
          3'b010: regval = reg2;
          3'b011: regval = reg3;
          3'b100: regval = reg4;
          3'b101: regval = reg5;
          3'b110: regval = reg6;
          3'b111: regval = reg7;

        endcase
      end else begin
        regval = {4'b0000 , instr[4], instr[2:0]};
    end
 
    case state_q

        3'b000: begin // Fetch
          address = inst_ptr;
          uio_out = address;
          
          if (opcode == 4'b1000) newval = regval; // load from reg
          else newval = alu_out_val; // use ALU output or just don't care

          if (opcode == 4'b0100) flags_d = (
            flags_q == 2'b00 && instr[3] || 
            flags_q == 2'b01 && instr[2] || 
            flags_q == 2'b10 && instr[1] ||
            flags_q == 2'b11 && instr[0]
            ) ? 2'b11 : 2'b00; 
          
          //
          else if (opcode == 4'b0101) begin
              flags_d[1] = (
                $signed(reg0) > $signed((instr[3] ? reg1 : 8'b0000_0000)) &&   instr[1]||
                reg0 == (instr[3] ? reg1 : 8'b0000_0000) && instr[0]
              ) ? 1'b1 : 1'b0

              flags_d[0] = (
                reg0 > (instr[3] ? reg1 : 8'b0000_0000) &&   instr[1]||
                reg0 == (instr[3] ? reg1 : 8'b0000_0000) && instr[0]
              ) ? 1'b1 : 1'b0
          end
          else flags_d = alu_out_flags; //  for the love of ..... don't write this thru on wrong instructions

        end

        3'b001 begin // Load
          address = regval;
          uio_out = address;
          newval = data_i; // loading from external memory
          // flags_d unused
        end

        3'b010 begin // Store Address
          address = regval;
          uio_out = address;
          // newval unused
          // flags_d unused
        end

        3'b011 begin // Store Data
          // address unused
          uio_out = memdata_out;
          // newval unused
          // flags_d unused
        end

        3'b100 begin // Jump  Address
          address = 8'b1111_1111
          uio_out = address;
          // newval unused
          // flags_d unused
        end

        3'b101 begin // Jump  Data
          // address unused
          uio_out = memdata_out;
          // newval unused
          // flags_d unused
        end
    endcase 
  end


  wire [7:0] alu_out_val;
  wire [1:0] alu_out_flags;

  // ALU
  tt_um_TscherterJunior_ALU ALU (
    .opcode_i(opcode),

    .acc_i(accval),
    .opcode_i(opval),

    .acc_o(alu_out_flags),
    .flags_o(alu_out_flags)
  )

  // FF datapath

  always @(posedge clk, rst_n) begin

    if(!reset_n) begin

      reg0 = 8'b0000_0000;
      reg1 = 8'b0000_0000;
      reg2 = 8'b0000_0000;
      reg3 = 8'b0000_0000;
      reg4 = 8'b0000_0000;
      reg5 = 8'b0000_0000;
      reg6 = 8'b0000_0000;
      reg7 = 8'b0000_0000;

      flags_q = 2'b00;
      inst_ptr = 8'b0000_0000;

    end
    else begin



    end
  
  end



  // END Data Path ---------------------------------------------


  /*
  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  */

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule


/*

case state_q

    3'b000: begin // Fetch

    end

    3'b001 begin // Load

    end

    3'b010 begin // Store Address

    end

    3'b011 begin // Store Data

    end

    3'b100 begin // Jump  Address

    end

    3'b101 begin // Jump  Data

    end

endcase 

*/