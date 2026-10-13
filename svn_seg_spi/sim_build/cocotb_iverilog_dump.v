module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("C:\\Users\\kevin\\Desktop\\projects\\fpga_class\\lab02\\sim_build\\spi_con.fst");
    end
    $dumpvars(0, spi_con);
end
endmodule
