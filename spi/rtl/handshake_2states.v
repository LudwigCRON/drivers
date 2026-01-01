
module handshake_2states #(
    parameter integer L = 'd2  
) (
    input  wire    src_clk,
    input  wire    src_rstb,
    input  wire    src_req_it,
    output wire    src_ack_it,
    input  wire    dst_clk,
    input  wire    dst_rstb,
    output wire    dst_req_it,
    input  wire    dst_ack_it
);

    reg [L-1:0] sync_src_dst;
    reg [L-1:0] sync_dst_src;
    reg         src_mem_req;
    reg         dst_mem_ack;

    // request
    always @(posedge src_clk, negedge src_rstb)
    begin
        if (!src_rstb)
            src_mem_req <= 1'd0;
        else if (src_req_it)
            src_mem_req <= ~src_mem_req;
    end

    always @(posedge dst_clk, negedge dst_rstb)
    begin
        if (!dst_rstb)
            sync_src_dst <= {L{1'd0}};
        else
            sync_src_dst <= {sync_src_dst[L-2:0], src_mem_req ^ src_req_it};
    end

    assign dst_req_it = ^sync_src_dst[L-1:L-2];
    
    // acknowledge
    always @(posedge dst_clk, negedge dst_rstb)
    begin
        if (!dst_rstb)
            dst_mem_ack <= 1'd0;
        else if (dst_ack_it)
            dst_mem_ack <= ~dst_mem_ack;
    end

    always @(posedge src_clk, negedge src_rstb)
    begin
        if (!src_rstb)
            sync_dst_src <= {L{1'd0}};
        else
            sync_dst_src <= {sync_dst_src[L-2:0], dst_mem_ack};
    end

    assign src_ack_it = ^sync_dst_src[L-1:L-2];

endmodule