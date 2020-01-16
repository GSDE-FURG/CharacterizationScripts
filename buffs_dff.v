module top (in1, in2, clk1, clk2, clk3, out);
  input in1, in2, clk1, clk2, clk3;
  output out;
  wire r1q, r2q, u1z, u2z;

  BUF_X1 BUF_X1 (.A(r2q), .Z(u1z));
  BUF_X2 BUF_X2 (.A(r2q), .Z(u1z));
  BUF_X4 BUF_X4 (.A(r2q), .Z(u1z));
  BUF_X8 BUF_X8 (.A(r2q), .Z(u1z));
  BUF_X16 BUF_X16 (.A(r2q), .Z(u1z));
  BUF_X32 BUF_X32 (.A(r2q), .Z(u1z));
  DFF_X1 DFF_X1 (.D(u2z), .CK(clk3), .Q(out));
endmodule // top
