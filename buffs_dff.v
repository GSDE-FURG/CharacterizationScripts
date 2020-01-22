module top (in1, in2, clk1, clk2, clk3, out);
  input in1, in2, clk1, clk2, clk3;
  output out;
  wire r1q, r2q, u1z, u2z;

  BUF_X1 BUF_X1 (.A(r2q), .Z(u1z));
  BUF_X2 abcdefghijk999666 (.A(r2q), .Z(u1z));
  BUF_X4 c (.A(r2q), .Z(u1z));
  BUF_X8 d (.A(r2q), .Z(u1z));
  BUF_X16 e (.A(r2q), .Z(u1z));
  BUF_X32 f (.A(r2q), .Z(u1z));
  DFF_X1 g (.D(u2z), .CK(clk3), .Q(out));
endmodule // top
