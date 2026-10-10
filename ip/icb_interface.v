// icb_interface.v 
// Acts as a slave on the ICB bus and interfaces with the internal register_file.

module icb_interface #(
    parameter BASE_ADDR = 32'h1001_4000
) (
    input wire clk,
    input wire rst_n,

    // ICB Bus Interface
    input wire        icb_cmd_valid,
    output wire       icb_cmd_ready,
    input wire [31:0] icb_cmd_addr,
    input wire        icb_cmd_read,
    input wire [31:0] icb_cmd_wdata,
    
    output wire       icb_rsp_valid,
    input wire        icb_rsp_ready,
    output wire[31:0] icb_rsp_rdata,

    // Interface to register_file.v
    output wire       reg_write_en,
    output wire [2:0] reg_addr_sel,
    output wire [31:0] reg_write_data,
    input wire [31:0] reg_read_data_muxed
);

    wire addr_hit = (icb_cmd_addr[31:5] == BASE_ADDR[31:5]);
    
    reg rsp_valid_reg;
    
    assign icb_cmd_ready = addr_hit && !rsp_valid_reg;
    
    wire cmd_fire = icb_cmd_valid && icb_cmd_ready;

    assign icb_rsp_valid = rsp_valid_reg;
    wire rsp_fire = icb_rsp_valid && icb_rsp_ready;

    assign reg_addr_sel = icb_cmd_addr[4:2];
    assign reg_write_data = icb_cmd_wdata;
    assign reg_write_en = cmd_fire && !icb_cmd_read;

    // --- Corrected Response Data and State Logic ---
    
    reg [31:0] rsp_rdata_reg;
    // The redundant `cmd_read_reg` has been removed.

    assign icb_rsp_rdata = rsp_rdata_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_valid_reg <= 1'b0;
            rsp_rdata_reg <= 32'd0;
        end else begin
            // When a command fires, prepare the response for the next cycle.
            if (cmd_fire) begin
                rsp_valid_reg <= 1'b1;

                // **THE FIX IS HERE:**
                // Load the response data register IMMEDIATELY based on the current command,
                // not a latched version of the command.
                if (icb_cmd_read) begin
                    // For a read, grab the data coming from the register file.
                    rsp_rdata_reg <= reg_read_data_muxed;
                end else begin
                    // For a write, the response data is typically 0.
                    rsp_rdata_reg <= 32'd0;
                end
            end 
            // When the master accepts our response, we can de-assert valid.
            else if (rsp_fire) begin
                rsp_valid_reg <= 1'b0;
            end
        end
    end

endmodule