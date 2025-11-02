module buffer_chain (
    input wire in,
    output wire out
);

    wire w1, w2, w3, w4, w5;

    BUFX1_HVT buf1 (.A(in), .Y(w1));
    BUFX1_LVT buf2 (.A(w1), .Y(w2));
    BUFX4_HVT buf3 (.A(w2), .Y(w3));
    BUFX1_LVT buf4 (.A(w3), .Y(w4));
    BUFX2_HVT buf5 (.A(w4), .Y(w5));
    BUFX1_LVT buf6 (.A(w5), .Y(out));

endmodule