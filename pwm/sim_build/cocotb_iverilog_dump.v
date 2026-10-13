module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("C:\\Users\\kevin\\Desktop\\projects\\fpga_class\\lab01\\sim_build\\counter.fst");
    end
    $dumpvars(0, counter);
end
endmodule
