module cocotb_iverilog_dump();
initial begin
    string dumpfile_path;    if ($value$plusargs("dumpfile_path=%s", dumpfile_path)) begin
        $dumpfile(dumpfile_path);
    end else begin
        $dumpfile("C:\\Users\\kevin\\Desktop\\projects\\fpga_class\\lab04\\sim\\sim_build\\video_sig_gen.fst");
    end
    $dumpvars(0, video_sig_gen);
end
endmodule
