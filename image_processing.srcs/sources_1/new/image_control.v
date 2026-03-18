`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/18/2026 12:34:25 AM
// Design Name: 
// Module Name: image_control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module image_control(
    input               i_clk,
    input               i_rst,
    input[7:0]          i_pixbuf,
    input               i_pixbuf_valid,
    output reg[71:0]    o_pixbuf,
    output              o_pixbuf_valid,
    output reg          o_intr
);
    // switch line buffer at pix_counter = 512
    reg[8:0]        pix_counter;
    reg[1:0]        curr_line_buffer_w;
    reg[3:0]        line_buffer_data_valid;
    reg[3:0]        line_buff_rd_data;
    reg[1:0]        curr_line_buffer_r;
    wire[23:0]      lb_data[3:0];
    reg[8:0]        rd_counter;
    reg             rd_line_buffer;
    reg[11:0]       total_pix_counter; // check total number of pixels counted, knows if line of pix is done
    reg             rd_state;
    
    localparam IDLE = 'b0, RD_BUFFER = 'b1;
    assign o_pixbuf_valid = rd_line_buffer;
    
    always @(posedge i_clk)
    begin
        if (i_rst)
            total_pix_counter <= 0;
        else
        begin
        //  getting data and not reading it atm
            if (i_pixbuf_valid & !rd_line_buffer)
                total_pix_counter <= total_pix_counter + 1;
            else if (!i_pixbuf_valid & rd_line_buffer)
                total_pix_counter <= total_pix_counter - 1;
        end
    end
    
    // state machine
    always @(posedge i_clk)
    begin
        if (i_rst)
        begin
            rd_state <= IDLE;
            rd_line_buffer <=  1'b0;
            o_intr <= 1'b0;
        end
        begin
            case (rd_state)
            IDLE:begin
                // 3 lines fully read, start streaming
                if (total_pix_counter >= 1536)
                begin
                    rd_line_buffer <= 1'b1;
                    rd_state <= RD_BUFFER;
                    o_intr <= 1'b1;
                end
            end
            RD_BUFFER:begin
                // 512th pixel read on this clock, go back
                // to idle and check if 3 lines are read
                // else go to idle and wait
                if (rd_counter == 511)
                begin
                    rd_state <= IDLE;
                end
            end
            endcase
        end
    end
    
    
    always @(posedge i_clk)
    begin
        if (i_rst)
            pix_counter <= 0;
        else
        begin
            if (i_pixbuf_valid)
                pix_counter <= pix_counter + 1;
        end
    end
    
    always @(posedge i_clk) begin
        if (i_rst)
            curr_line_buffer_w <= 0;
        else if ((pix_counter == 511) && i_pixbuf_valid)
            curr_line_buffer_w <= curr_line_buffer_w + 1;
    end
    
    always @(*)
    begin
        line_buffer_data_valid = 4'h0;
        line_buffer_data_valid[curr_line_buffer_w] = i_pixbuf_valid;
    end
    
    always @(posedge i_clk)
    begin
        if (i_rst)
            rd_counter <= 0;
        begin
            if (rd_line_buffer)
                rd_counter <= rd_counter + 1;
        end            
    end
    
    always @(posedge i_clk)
    begin
        if (i_rst)
            begin
                curr_line_buffer_r <= 0;
            end
        else
        begin
            if (rd_counter == 511 & rd_line_buffer)
                curr_line_buffer_r <= curr_line_buffer_r + 1;
        end
    end
    
    always @(*) begin
        o_pixbuf = {
            lb_data[(curr_line_buffer_r + 2) & 2'b11],
            lb_data[(curr_line_buffer_r + 1) & 2'b11],
            lb_data[(curr_line_buffer_r + 0) & 2'b11]
        };
    end
    
    // sliding window
    always @(*)
    begin
        for (i=0; i<4; i=i+1) begin
            line_buff_rd_data[i] = (i == curr_line_buffer_r) ? 1'b0 : rd_line_buffer;
        end
    end
    
    // genvar cuz ceebs writing same thing again and again
    genvar j;
    generate
        for (j=0; j<4; j=i+1) begin :  line_buffers
            line_buffer lb (
                .i_clk(i_clk),
                .i_rst(i_rst),
                .i_data(i_pixbuf),
                .i_data_valid(line_buffer_data_valid[j]),
                .o_data(lb_data[j]),
                .i_rd_data(line_buff_rd_data[j])
            );
        end
    endgenerate
endmodule
