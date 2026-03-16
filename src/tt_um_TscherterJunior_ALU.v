/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_TscherterJunior_ALU (
    input wire [3:0] opcode_i,

    input  wire [7:0] acc_i,    
    input wire [7:0] operand_i, 

    output reg [7:0] acc_o,  
    output reg [1:0] flags_o

);

    reg [8:0] tempres;

    //enum bit[] {ADD = 4b'0010, SUB = 4b'0011, XOR = 4b'0111, AND = 4b'1100, OR = 4b'}

    always @(*) begin
        
        acc_o = 8'b0000_00000;
        flags_o = 2'b00;
        tempres = 8'b0000_00000;

        if(opcode_i[3:1] == 3'b000) begin // ADD imediate

                tempres = acc_i + operand_i;
                acc_o = tempres[7:0];
                flags_o[1] = tempres[8]; // carry
                flags_o[0] = (acc_i[7] == operand_i[7]) && (acc_i[7] != tempres[7]);

        end else begin

            case (opcode_i)
                4'b0010 : begin // ADD
                    tempres = acc_i + operand_i;
                    acc_o = tempres[7:0];
                    flags_o[1] = tempres[8]; // carry
                    flags_o[0] = (acc_i[7] == operand_i[7]) && (acc_i[7] != tempres[7]);

                end
                4'b0011 : begin // SUB
                    tempres = acc_i - operand_i;
                    acc_o = tempres[7:0];
                    flags_o[1] = tempres[8]; // carry
                    flags_o[0] = (~acc_i[7] & operand_i[7] & tempres[7]) || (acc_i[7] & ~operand_i[7] & ~tempres[7]);

                end
                4'b0111 : begin // XOR
                    acc_o = acc_i ^ operand_i;
                    flags_o[0] = (acc_o == 8'b0);
                    flags_o[1] = ~^acc_o; //parity
                end
                4'b1100 : begin // And
                    acc_o = acc_i & operand_i;
                    flags_o[0] = (acc_o == 8'b0);
                    flags_o[1] = ~^acc_o; //parity
                end            
                4'b1101 : begin // OR
                    acc_o = acc_i | operand_i;
                    flags_o[0] = (acc_o == 8'b0);
                    flags_o[1] = ~^acc_o; //parity
                end   
                4'b1110 : begin // shift left logical
                    acc_o = acc_i << operand_i[2:0];
                    flags_o[0] = (acc_o == 8'b0);
                    flags_o[1] = acc_o[7]; //sign
                end   
                4'b1111 : begin // shift right logical
                    acc_o = acc_i >> operand_i[2:0];
                    flags_o[0] = (acc_o == 8'b0);
                    flags_o[1] = acc_o[7]; //sign
                end   
                default : begin
                    acc_o = '0;
                    flags_o = '0;
                end
            endcase

        end

    end

endmodule