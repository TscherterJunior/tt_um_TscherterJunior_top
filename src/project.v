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


// data path wires

  // Instruction data 
  reg [7:0] used_instruction;
  reg [3:0] opcode;
  reg [3:0] decide_mask;
  reg [3:0] compare_mode;

  reg [2:0] used_acc;
  reg [2:0] used_reg;

  reg [7:0] imediate;

  reg [7:0] mem_address;
  reg [7:0] mem_write_data;

  // Operand values
  reg [7:0] operand_primary, operand_secondary;

  // Register value sources
  reg [7:0] alu_out_val;

  reg [7:0] dest_reg_oldvalue;
  reg [7:0] dest_reg_newvalue;

  // Flag sources
  reg [1:0] decide_flags;
  reg [1:0] compare_flags;
  reg [1:0] alu_out_flags;

// Defining ALL FFs

  // CPU Registers
  reg [7:0] reg0_q, reg0_d;
  reg [7:0] reg1_q, reg1_d;
  reg [7:0] reg2_q, reg2_d;
  reg [7:0] reg3_q, reg3_d;

  reg [7:0] reg4_q, reg4_d;
  reg [7:0] reg5_q, reg5_d;
  reg [7:0] reg6_q, reg6_d;
  reg [7:0] reg7_q, reg7_d;

  // CPU Flags
  reg [1:0] flags_q, flags_d;

  // Instruction Pointer
  reg [7:0] instruction_pointer_q, instruction_pointer_d;

  // Instruction Buffer
  reg [7:0] instruction_buffer_q,instruction_buffer_d;

  // CPU FSM
  reg [2:0] state_q, state_d;
  
// Renaming Physical Pins
  assign uio_oe = 8'b1111_1111;

  // input wires renamed
  wire  [7:0] data_i;
  reg   [7:0] data_o;
  assign data_i = ui_in;

  // output wires renamed
  reg write_en_o;
  reg instr_en_o;

  assign uio_out = data_o;

  assign uo_out[0] = write_en_o;
  assign uo_out[1] = instr_en_o;
  assign uo_out[4:2] = state_d; // unused uo_out pins(repurpouse for driving leds if time remains)
  assign uo_out[7:5] = state_q;

// Defining Constants

  // CPU FSM States
  localparam Fetch_state          = 3'b000;
  localparam Load_state           = 3'b001;
  localparam Store_Address_state  = 3'b010;
  localparam Store_Data_state     = 3'b011;
  localparam Jump_Address_state   = 3'b100;
  localparam Jump_Data_state      = 3'b101;

  // Register codes
  localparam Reg0  = 3'b000;
  localparam Reg1  = 3'b001;
  localparam Reg2  = 3'b010;
  localparam Reg3  = 3'b011;
  localparam Reg4  = 3'b100;
  localparam Reg5  = 3'b101;
  localparam Reg6  = 3'b110;
  localparam Reg7  = 3'b111;


  // Opcodes
  localparam Addi_opc_3 = 3'b000;
  //----------------------------;
  //localparam Add_opc    = 4'b0010;
  //localparam Sub_opc    = 4'b0011;

  localparam Dcd_opc    = 4'b0100;
  localparam Cmp_opc    = 4'b0101;
  localparam Jmp_opc    = 4'b0110;
  localparam Xor_opc    = 4'b0111;

  localparam Ldr_opc    = 4'b1000;
  localparam Str_opc    = 4'b1001;
  localparam Ldm_opc    = 4'b1010;
  localparam Stm_opc    = 4'b1011;

  //localparam And_opc    = 4'b1100;
  //localparam Or_opc     = 4'b1101;
  //localparam Sll_opc    = 4'b1110;
  //localparam Srl_opc    = 4'b1111;


// CPU FSM 
  // Next State Comb
  always @(*) begin

      // Default state
      state_d =  Fetch_state;

      case (state_q) 
        Fetch_state: begin
            case (opcode)
              Ldm_opc : state_d = Load_state;
              Stm_opc : state_d = Store_Address_state;
              Jmp_opc : begin
                if(used_instruction[3])  state_d = Jump_Address_state;
                else          state_d = Fetch_state;
              end
              default : state_d = Fetch_state;            
          endcase 
        end
        Load_state: state_d = Fetch_state;
        Store_Address_state: state_d = Store_Data_state;
        Store_Data_state: state_d = Fetch_state;
        Jump_Address_state: state_d = Jump_Data_state;
        Jump_Data_state: state_d = Fetch_state;
        default : state_d = Fetch_state; // should never be hit
      endcase
  end

  // Assign FF
  always @(posedge clk, rst_n) begin
    if(! rst_n) state_q <= Fetch_state;
    else        state_q <= state_d;
  end

  always @(posedge clk, rst_n) begin
    if(!rst_n) begin
  // CPU Registers
      reg0_q <= 8'b0000_0000;
      reg1_q <= 8'b0000_0000;
      reg2_q <= 8'b0000_0000;
      reg3_q <= 8'b0000_0000;

      reg4_q <= 8'b0000_0000;
      reg5_q <= 8'b0000_0000;
      reg6_q <= 8'b0000_0000;
      reg7_q <= 8'b0000_0000;

      // CPU Flags
      flags_q <= 2'b00;

      // Instruction Pointer
      instruction_pointer_q <= 8'b0000_0000;

      // Instruction Buffer
      instruction_buffer_q <= 8'b0000_0000;
    end else begin
      reg0_q <= reg0_d;
      reg1_q <= reg1_d;
      reg2_q <= reg2_d;
      reg3_q <= reg3_d;

      reg4_q <= reg4_d;
      reg5_q <= reg5_d;
      reg6_q <= reg6_d;
      reg7_q <= reg7_d;

      flags_q <= flags_d;

      instruction_pointer_q <= instruction_pointer_d;

      instruction_buffer_q <= instruction_buffer_d;
    end
  end

  // Output gen:

    // Wires driven by FSM output (these depend on FSM state only)
    // instr_en_o
    // write_en_o
    // use_buffered_instr

  reg use_buffered_instr;

  always @(*) begin
      
      // defaults
      instr_en_o = 1'b0;
      write_en_o = 1'b0;
      use_buffered_instr = 1'b1;

      case (state_q)
        Fetch_state: begin 
          instr_en_o = 1'b1;
          write_en_o = 1'b0;
          use_buffered_instr = 1'b0;
        end
        Load_state: begin
          instr_en_o = 1'b0;
          write_en_o = 1'b0;
          use_buffered_instr = 1'b1;
        end
        Store_Address_state: begin
          instr_en_o = 1'b0;
          write_en_o = 1'b1;
          use_buffered_instr = 1'b1;
        end
        Store_Data_state: begin
          instr_en_o = 1'b0;
          write_en_o = 1'b1;
          use_buffered_instr = 1'b1;
        end
        Jump_Address_state: begin 
          instr_en_o = 1'b1;
          write_en_o = 1'b1;
          use_buffered_instr = 1'b1;
        end
        Jump_Data_state: begin 
          instr_en_o = 1'b1;
          write_en_o = 1'b1;
          use_buffered_instr = 1'b1;
        end
        default : begin // shpuld never be hit
          instr_en_o = 1'b1;
          write_en_o = 1'b0;
          use_buffered_instr = 1'b0;
        end 
      endcase
  end


// Controlsignal Generation

  // Control signals
  reg write_to_reg;
  reg dest_reg;

  // flag sources
  reg source_flag_decide;
  reg source_flag_compare;
  reg source_flag_alu;

  reg use_imediate;

  reg jump;

  // reg sources
  reg source_reg_alu;
  reg source_reg_acc;
  reg source_reg_reg;
  reg source_reg_mem;

  // address sources
  reg source_address_ip;
  reg source_address_reg;

  always @(*) begin
  
      write_to_reg = (
        state_q == Fetch_state && !(opcode == Dcd_opc || opcode == Cmp_opc || opcode == Jmp_opc || opcode == Stm_opc)
        || state_q == Load_state
      );

      dest_reg = ((opcode == Str_opc) ? used_reg : used_acc);

      source_flag_decide  = opcode == Dcd_opc && state_q == Fetch_state;
      source_flag_compare = opcode == Cmp_opc && state_q == Fetch_state;
      source_flag_alu     = (opcode[3:2] == 2'b00 || opcode[3:2] == 2'b11 || opcode == Xor_opc) && state_q == Fetch_state;

      use_imediate        = used_instruction[7:5] == Addi_opc_3;
      jump                = (opcode == Jmp_opc && flags_q[0] && state_q == Fetch_state) || state_q == Jump_Data_state;

      source_reg_alu     = source_flag_alu;
      source_reg_acc      = opcode == Str_opc && state_q == Fetch_state;
      source_reg_reg      = opcode == Ldr_opc && state_q == Fetch_state;
      source_reg_mem      = opcode == Ldm_opc && state_q == Load_state;

      source_address_ip   = state_q == Fetch_state;
      source_address_reg  = state_q == Load_state || state_q == Store_Address_state;

  end



// Datapath


  always @(*) begin

    used_instruction  = use_buffered_instr ? instruction_buffer_q : instruction_buffer_d;
    opcode            = used_instruction[7:4];
    decide_mask       = used_instruction[3:0];
    compare_mode      = used_instruction[3:0];
    used_acc          = used_instruction[3] ? Reg1 : Reg0;
    used_reg          = used_instruction[2:0];

    imediate          = {4'b0000, used_instruction[4], used_instruction[2:0]};

    operand_primary   = used_acc == Reg0 ? reg0_q : reg1_d;
    operand_secondary = use_imediate      ? imediate  :
                        ((used_reg == Reg0)  ? reg0_q    :
                        ((used_reg == Reg1)  ? reg1_q    :
                        ((used_reg == Reg2)  ? reg2_q    :
                        ((used_reg == Reg3)  ? reg3_q    :

                        ((used_reg == Reg4)  ? reg4_q    :
                        ((used_reg == Reg5)  ? reg5_q    :
                        ((used_reg == Reg6)  ? reg6_q    :
                        reg7_q)))))));

    dest_reg_oldvalue = ((dest_reg == Reg0)  ? reg0_q    :
                        ((dest_reg == Reg1)  ? reg1_q    :
                        ((dest_reg == Reg2)  ? reg2_q    :
                        ((dest_reg == Reg3)  ? reg3_q    :

                        ((dest_reg == Reg4)  ? reg4_q    :
                        ((dest_reg == Reg5)  ? reg5_q    :
                        ((dest_reg == Reg6)  ? reg6_q    :
                        reg7_q)))))));

    dest_reg_newvalue = source_reg_acc ? operand_primary    :
                        source_reg_alu ? alu_out_val        :
                        source_reg_mem ? data_i             :
                        source_reg_reg ? operand_secondary  :
                        dest_reg_oldvalue;


    decide_flags =  (flags_q == 2'b00 && decide_mask[3] || 
                    flags_q == 2'b01 && decide_mask[2] || 
                    flags_q == 2'b10 && decide_mask[1] ||
                    flags_q == 2'b11 && decide_mask[0])
                    ? 2'b11 : 2'b00;

    compare_flags[1] = (
                ($signed(reg0_q) > $signed((compare_mode[3] ? reg1_q : 8'b0000_0000)) &&   compare_mode[1] ||
                reg0_q == (compare_mode[3] ? reg1_q : 8'b0000_0000) && compare_mode[0]
              )) ? 1'b1 : 1'b0; 

    compare_flags[0] = (
                (reg0_q > (compare_mode[3] ? reg1_q : 8'b0000_0000) &&   compare_mode[1] ||
                reg0_q == (compare_mode[3] ? reg1_q : 8'b0000_0000) && compare_mode[0]
              )) ? 1'b1 : 1'b0;

    mem_address = (source_address_ip   ? instruction_pointer_q :
                  (source_address_reg  ? operand_secondary     :
                  8'b1111_1111)); // constand address used for paged jumps
    
    mem_write_data = ((state_q == Store_Data_state) ?  operand_primary : reg7_q);          // source for page number when jumping

    data_o = (state_q == Fetch_state || state_q == Store_Address_state ||
                        state_q == Load_state || state_q == Jump_Address_state ) ?
                        mem_address : mem_write_data;
    

  end

  // Instanciate ALU
  tt_um_TscherterJunior_ALU ALU (
    .opcode_i(opcode),

    .acc_i(operand_primary),
    .operand_i(operand_secondary),

    .acc_o(alu_out_val),
    .flags_o(alu_out_flags)
  );

  // New FF values

  always @(*) begin

    reg0_d = (dest_reg == Reg0 && write_to_reg) ? dest_reg_newvalue : reg0_q;
    reg1_d = (dest_reg == Reg1 && write_to_reg) ? dest_reg_newvalue : reg1_q;
    reg2_d = (dest_reg == Reg2 && write_to_reg) ? dest_reg_newvalue : reg2_q;
    reg3_d = (dest_reg == Reg3 && write_to_reg) ? dest_reg_newvalue : reg3_q;

    reg4_d = (dest_reg == Reg4 && write_to_reg) ? dest_reg_newvalue : reg4_q;
    reg5_d = (dest_reg == Reg5 && write_to_reg) ? dest_reg_newvalue : reg5_q;
    reg6_d = (dest_reg == Reg6 && write_to_reg) ? dest_reg_newvalue : reg6_q;
    reg7_d = (dest_reg == Reg7 && write_to_reg) ? dest_reg_newvalue : reg7_q;

    // CPU Flags
    flags_d = (source_flag_decide  ? decide_flags :
              (source_flag_alu     ? alu_out_flags :
              (source_flag_compare ? compare_flags :
              flags_q)));


    // Instruction Pointer
    instruction_pointer_d = jump ? operand_secondary : (instruction_pointer_q + 8'b0000_0001);

    // Instruction Buffer
    instruction_buffer_d = state_q == Fetch_state ? data_i : instruction_buffer_q;

  end


// Handle Remaining Pins


  /*
  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  */

  wire _unused_internal = &{compare_mode[2]};

  // List all unused inputs to prevent warnings
  wire _unused = &{ena,uio_in};

endmodule

