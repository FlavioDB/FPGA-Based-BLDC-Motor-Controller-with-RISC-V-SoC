/*
 * Module: sine_rom
 * Description: A 64-entry, 8-bit read-only memory (ROM) storing
 *              one quadrant of a sine wave.
 */
module sine_rom (
    input      [5:0]  addr,    // Address (0-63)
    output reg [7:0]  q        // Data Out (8-bit sine value)
);

    // Memory declaration
    reg [7:0] mem [0:63];

    // Read logic
    always @(*) begin
        q = mem[addr];
    end

    // Memory initialization
    initial begin
// Corrected full-range values (0-255) for the sine LUT
mem[0] = 8'd0;
mem[1] = 8'd6;
mem[2] = 8'd13;
mem[3] = 8'd19;
mem[4] = 8'd25;
mem[5] = 8'd32;
mem[6] = 8'd38;
mem[7] = 8'd44;
mem[8] = 8'd51;
mem[9] = 8'd57;
mem[10] = 8'd63;
mem[11] = 8'd69;
mem[12] = 8'd75;
mem[13] = 8'd81;
mem[14] = 8'd87;
mem[15] = 8'd93;
mem[16] = 8'd99;
mem[17] = 8'd105;
mem[18] = 8'd111;
mem[19] = 8'd116;
mem[20] = 8'd122;
mem[21] = 8'd127;
mem[22] = 8'd133;
mem[23] = 8'd138;
mem[24] = 8'd144;
mem[25] = 8'd149;
mem[26] = 8'd154;
mem[27] = 8'd159;
mem[28] = 8'd164;
mem[29] = 8'd169;
mem[30] = 8'd173;
mem[31] = 8'd178;
mem[32] = 8'd183;
mem[33] = 8'd187;
mem[34] = 8'd191;
mem[35] = 8'd195;
mem[36] = 8'd199;
mem[37] = 8'd203;
mem[38] = 8'd207;
mem[39] = 8'd211;
mem[40] = 8'd214;
mem[41] = 8'd218;
mem[42] = 8'd221;
mem[43] = 8'd224;
mem[44] = 8'd227;
mem[45] = 8'd230;
mem[46] = 8'd232;
mem[47] = 8'd235;
mem[48] = 8'd237;
mem[49] = 8'd240;
mem[50] = 8'd242;
mem[51] = 8'd244;
mem[52] = 8'd245;
mem[53] = 8'd247;
mem[54] = 8'd249;
mem[55] = 8'd250;
mem[56] = 8'd251;
mem[57] = 8'd252;
mem[58] = 8'd253;
mem[59] = 8'd254;
mem[60] = 8'd254;
mem[61] = 8'd255;
mem[62] = 8'd255;
mem[63] = 8'd255;

    end

endmodule