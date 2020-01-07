/*
 *  TuMan32 -- A Small but pipelined RISC-V (RV32I) Processor Core
 *
 *  Copyright (C) 2019-2020  Junnan Li <lijunnan@nudt.edu.cn>
 *
 *  Permission to use, copy, modify, and/or distribute this code for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *	To AoTuman, my dear cat, thanks for your company.
 */

`timescale 1 ns / 1 ps


module conf_mem(
input	clk,
input	resetn,

input 				data_in_valid,
input 		[133:0]	data_in,
output reg			data_out_valid,
output reg	[133:0]	data_out,

output reg			conf_rden_itcm,
output reg			conf_wren_itcm,
output reg	[31:0]	conf_addr_itcm,
output reg	[31:0]	conf_wdata_itcm,
input		[31:0]	conf_rdata_itcm,

output reg			conf_sel_dtcm,
output reg			conf_rden_dtcm,
output reg			conf_wren_dtcm,
output reg	[31:0]	conf_addr_dtcm,
output reg	[31:0]	conf_wdata_dtcm,
input		[31:0]	conf_rdata_dtcm,

input 				print_valid,
input 		[7:0]	print_value
);

reg [3:0]	state_conf, state_out;
parameter	IDLE_S		= 4'd0,
			READ_META_1	= 4'd1,
			READ_HEAD_0	= 4'd2,
			WR_SEL_S	= 4'd3,
			RD_SEL_S	= 4'd4,
			WR_PROG_S	= 4'd5,
			RD_PROG_S	= 4'd6,
			DISCARD_S	= 4'd7,
			SEND_META_0	= 4'd1,
			SEND_META_1	= 4'd2,
			SEND_HEAD_0	= 4'd3,
			SEND_HEAD_1	= 4'd4,
			SEND_HEAD_2	= 4'd5,
			SEND_HEAD_3	= 4'd6;

reg 		read_sel_tag[1:0];

//reg [1:0]	gen_ack_tag;

always @(posedge clk or negedge resetn) begin
	if (!resetn) begin
		// reset
		conf_rden_itcm <= 1'b0;
		conf_wren_itcm <= 1'b0;
		conf_addr_itcm <= 32'b0;
		conf_wdata_itcm <= 32'b0;
		conf_sel_dtcm <= 1'b1;
		conf_rden_dtcm <= 1'b0;
		conf_wren_dtcm <= 1'b0;
		conf_addr_dtcm <= 32'b0;
		conf_wdata_dtcm <= 32'b0;

		state_conf <= IDLE_S;
		read_sel_tag[0] <= 1'b0;
	end
	else begin
		case(state_conf)
			IDLE_S: begin
				conf_wren_itcm <= 1'b0;
				conf_wren_dtcm <= 1'b0;
				if((data_in_valid == 1'b1)&&(data_in[133:132] == 2'b01)) begin
					state_conf <= READ_META_1;
				end
				else begin
					state_conf <= IDLE_S;
				end
			end
			READ_META_1: begin
				state_conf <= READ_HEAD_0;
			end
			READ_HEAD_0: begin
				/** write sel */
				if(data_in[31:16] == 16'h9001) begin
					state_conf <= WR_SEL_S;
				end
				/** read sel */
				else if(data_in[31:16] == 16'h9002) begin
					state_conf <= RD_SEL_S;
				end
				/** write program */
				else if(data_in[31:16] == 16'h9003) begin
					state_conf <= WR_PROG_S;
				end
				/** read program */
				else if(data_in[31:16] == 16'h9004) begin
					state_conf <= RD_PROG_S;
				end
				else begin
					state_conf <= DISCARD_S;
				end
			end
			WR_SEL_S: begin
				conf_sel_dtcm <= data_in[16];
				state_conf <= DISCARD_S;
				// gen_ack_tag[0] <= ~gen_ack_tag[0];
			end
			RD_SEL_S: begin
				state_conf <= DISCARD_S;
				read_sel_tag[0] <= ~read_sel_tag[0];
				// gen_ack_tag[0] <= ~gen_ack_tag[0];
			end
			WR_PROG_S: begin
				conf_wren_itcm <= 1'b1;
				conf_wren_dtcm <= 1'b1;
				conf_addr_itcm <= data_in[47:16];
				conf_wdata_itcm<= data_in[79:48];
				conf_addr_dtcm <= data_in[47:16];
				conf_wdata_dtcm<= data_in[79:48];

				if(data_in[133:132] == 2'b10) begin
					state_conf <= IDLE_S;
				end
				else begin
					state_conf <= WR_PROG_S;
				end
			end
			RD_PROG_S: begin
				// TODO:
				state_conf <= DISCARD_S;
				conf_rden_itcm <= 1'b1;
				conf_addr_itcm <= data_in[47:16];
				conf_rden_dtcm <= 1'b1;
				conf_addr_dtcm <= data_in[47:16];
			end
			DISCARD_S: begin
				conf_rden_itcm <= 1'b0;
				conf_rden_dtcm <= 1'b0;
				if(data_in[133:132] == 2'b10)
					state_conf <= IDLE_S;
				else
					state_conf <= DISCARD_S;
			end
			default: begin
				state_conf <= IDLE_S;
			end
		endcase
	end
end




reg [31:0]	addr_temp[1:0];
reg 		rden_temp[1:0];
reg 		rdreq_rdata;
wire 		empty_rdata;
wire[95:0]	q_rdata;

reg 		rdreq_value;
wire 		empty_value;
wire[7:0]	q_value;

always @(posedge clk or negedge resetn) begin
	if (!resetn) begin
		// reset
		addr_temp[0] <= 32'b0;
		addr_temp[1] <= 32'b0;
		rden_temp[0] <= 1'b0;
		rden_temp[1] <= 1'b0;
	end
	else begin
		addr_temp[0] <= conf_addr_itcm;
		addr_temp[1] <= addr_temp[0];
		rden_temp[0] <= conf_rden_itcm;
		rden_temp[1] <= rden_temp[0];
	end
end

// fifo rdata_buffer(
// 	.aclr(!resetn),
// 	.clock(clk),
// 	.data({conf_rdata_itcm, conf_rdata_dtcm, addr_temp[1]}),
// 	.rdreq(rdreq_rdata),
// 	.wrreq(rden_temp[1]),
// 	.empty(empty_rdata),
// 	.full(),
// 	.q(q_rdata),
// 	.usedw()
// );
// defparam
// 	rdata_buffer.width = 96,
// 	rdata_buffer.depth = 6,
// 	rdata_buffer.words = 64;

	fifo_96_64 rdata_buffer(
	.clk(clk),
	.srst(!resetn),
	.din({conf_rdata_itcm, conf_rdata_dtcm, addr_temp[1]}),
	.wr_en(rden_temp[1]),
	.rd_en(rdreq_rdata),
	.dout(q_rdata),
	.full(),
	.empty(empty_rdata)
	);

// fifo value_buffer(
// 	.aclr(!resetn),
// 	.clock(clk),
// 	.data(print_value),
// 	.rdreq(rdreq_value),
// 	.wrreq(print_valid),
// 	.empty(empty_value),
// 	.full(),
// 	.q(q_value),
// 	.usedw()
// );
// defparam
// 	value_buffer.width = 8,
// 	value_buffer.depth = 6,
// 	value_buffer.words = 64;

	fifo_8_64 value_buffer(
	.clk(clk),
	.srst(!resetn),
	.din(print_value),
	.wr_en(print_valid),
	.rd_en(rdreq_value),
	.dout(q_value),
	.full(),
	.empty(empty_value)
	);

always @(posedge clk or negedge resetn) begin
	if (!resetn) begin
		// reset
		data_out_valid <= 1'b0;
		data_out <= 134'b0;
		read_sel_tag[1] <= 1'b0;

		rdreq_rdata <= 1'b0;
		rdreq_value <= 1'b0;
	end
	else begin
		case(state_out)
			IDLE_S: begin
				data_out_valid <= 1'b0;
				if(read_sel_tag[1] != read_sel_tag[0] || empty_rdata == 1'b0 ||
					empty_value == 1'b0) begin
					state_out <= SEND_META_0;
				end
				else begin
					state_out <= IDLE_S;
				end
			end
			SEND_META_0: begin
				data_out_valid <= 1'b1;
				data_out <= {2'b01,4'b0,1'b0,1'b0,6'b0,2'b0,6'd1,3'b0,1'b0,12'd96,96'b0};
				state_out <= SEND_META_1;
			end
			SEND_META_1: begin
				data_out <= {2'b11,4'b0,128'b0};
				state_out <= SEND_HEAD_0;
			end
			SEND_HEAD_0: begin
				if(read_sel_tag[1] != read_sel_tag[0])
					data_out[31:0] <= {16'h9002,16'b0};
				else if(empty_rdata == 1'b0) begin
					data_out[31:0] <= {16'h9004,16'b0};
					rdreq_rdata <= 1'b1;
				end
				else begin
					data_out[31:0] <= {16'h9005,16'b0};
					rdreq_value <= 1'b1;
				end
				data_out[133:32] <= {2'b11,4'b0,48'd1,48'd2};
				state_out <= SEND_HEAD_1;
			end
			SEND_HEAD_1: begin
				rdreq_rdata <= 1'b0;
				rdreq_value <= 1'b0;
				if(read_sel_tag[1] != read_sel_tag[0]) begin
					data_out[111:16] <= {95'b0,conf_sel_dtcm};
					read_sel_tag[1]<= read_sel_tag[0];
				end
				else if(rdreq_rdata == 1'b1)
					data_out[111:16] <= q_rdata;
				else
					data_out[111:16] <= {88'b0,q_value};
				data_out[133:112] <= {2'b11,4'b0,16'b0};
				data_out[15:0] <= 16'b0;
				state_out <= SEND_HEAD_2;
			end
			SEND_HEAD_2: begin
				data_out <= {2'b11,4'b0,128'd1};
				state_out <= SEND_HEAD_3;
			end
			SEND_HEAD_3: begin
				data_out <= {2'b10,4'b0,128'd2};
				state_out <= IDLE_S;
			end
			default: begin
				state_out <= IDLE_S;
			end
		endcase
	end
end


endmodule