import cocotb
import os
import sys
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge
from cocotb.utils import get_sim_time as gst
from cocotb_tools.runner import get_runner

test_file = os.path.basename(__file__).replace(".py", "")

@cocotb.test()
async def test_vsg(dut):
    """cocotb test for testing the video signal generator (waveform generation only)"""
    dut._log.info("Starting simulation...")
    
    # Start the clock
    cocotb.start_soon(Clock(dut.pixel_clk, 10, unit="ns").start())

    # Apply Reset
    await ClockCycles(dut.pixel_clk, 3)
    dut._log.info("Holding reset...")
    dut.rst.value = 1
    await ClockCycles(dut.pixel_clk, 3)
    
    await FallingEdge(dut.pixel_clk)
    dut._log.info("Setting reset to 0")
    dut.rst.value = 0
    
    dut._log.info(f"Currently @ {gst('ns')} ns in sim. Generating waveform...")
    
    # Let the simulation run for exactly 2000 clock cycles.
    # At 16x16 pixels per frame, one frame takes 256 cycles.
    # 2000 cycles will generate nearly 8 frames of data to look at.
    for _ in range(2000):
        await RisingEdge(dut.pixel_clk)
        
        # We will still print a message when new_frame goes high so you 
        # can track progress in the terminal, but we won't crash if it fails!
        try:
            if dut.new_frame.value == 1:
                dut._log.info(f"Time: {gst('ns')} ns | new_frame triggered! Frame count is now: {dut.frame_count.value}")
        except ValueError:
            # Ignore errors if new_frame is undefined ('x' or 'z')
            pass

    dut._log.info("Simulation complete! You can now open sim_build/video_sig_gen.fst in GTKWave.")

def vsg_runner():
    """Simulate the video_sig_gen using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    
    sources = [proj_path / "hdl" / "video_sig_gen.sv"] 
    build_test_args = ["-Wall"]
    
    # Scaled-down parameters for a fast 16x16 frame test
    parameters = {
        'ACTIVE_H_PIXELS': 10,
        'H_FRONT_PORCH': 2,
        'H_SYNC_WIDTH': 2,
        'H_BACK_PORCH': 2,
        'ACTIVE_LINES': 10,
        'V_FRONT_PORCH': 2,
        'V_SYNC_WIDTH': 2,
        'V_BACK_PORCH': 2,
        'FPS': 4
    }
    
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "video_sig_gen"
    runner = get_runner(sim)
    
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),
        build_dir=proj_path / "sim" / "sim_build",
        waves=True
    )
    
    run_test_args = []
    
    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module=test_file,
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    vsg_runner()