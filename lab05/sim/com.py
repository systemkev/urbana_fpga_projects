import os
import sys
from pathlib import Path
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, with_timeout
from cocotb.result import SimTimeoutError
from cocotb.utils import get_sim_time as gst
from cocotb_tools.runner import get_runner

test_file = os.path.basename(__file__).replace(".py", "")

async def reset_dut(dut):
    """Helper function to reset the module."""
    dut.rst.value = 1
    dut.pixel_x.value = 0
    dut.pixel_y.value = 0
    dut.pixel_valid.value = 0
    dut.calculate.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 3)

@cocotb.test()
async def test_diagonal_line(dut):
    # 700 pixels, x and y increasing from 0 to 699
    dut._log.info("Starting test_diagonal_line...")
    cocotb.start_soon(Clock(dut.clk, 13.468, units="ns").start())
    await reset_dut(dut)
    
    for i in range(700):
        dut.pixel_x.value = i
        dut.pixel_y.value = i
        dut.pixel_valid.value = 1
        await RisingEdge(dut.clk)
        
    dut.pixel_valid.value = 0
    dut.calculate.value = 1
    await RisingEdge(dut.clk)
    dut.calculate.value = 0
    
    # wait for the FSM to finish dividing
    await with_timeout(RisingEdge(dut.com_valid), 10000, "ns")
    
    x_val = dut.com_x.value.integer
    y_val = dut.com_y.value.integer
    
    assert x_val in [348, 349], f"Expected 348 or 349, got {x_val}"
    assert y_val in [348, 349], f"Expected 348 or 349, got {y_val}"

@cocotb.test()
async def test_horizontal_line(dut):
    # 700 pixels, x increasing 0 to 699, y always 10
    dut._log.info("Starting test_horizontal_line...")
    cocotb.start_soon(Clock(dut.clk, 13.468, units="ns").start())
    await reset_dut(dut)
    
    for i in range(700):
        dut.pixel_x.value = i
        dut.pixel_y.value = 10
        dut.pixel_valid.value = 1
        await RisingEdge(dut.clk)
        
    dut.pixel_valid.value = 0
    dut.calculate.value = 1
    await RisingEdge(dut.clk)
    dut.calculate.value = 0
    
    await with_timeout(RisingEdge(dut.com_valid), 10000, "ns")
    
    x_val = dut.com_x.value.integer
    y_val = dut.com_y.value.integer
    
    assert x_val in [348, 349], f"Expected x to be 348 or 349, got {x_val}"
    assert y_val == 10, f"Expected y to be 10, got {y_val}"

@cocotb.test()
async def test_repeated_frames(dut):
    # system must work repeatedly on one frame after the other
    dut._log.info("Starting test_repeated_frames...")
    cocotb.start_soon(Clock(dut.clk, 13.468, units="ns").start())
    await reset_dut(dut)
    
    # frame 1
    for _ in range(100):
        dut.pixel_x.value = 50
        dut.pixel_y.value = 60
        dut.pixel_valid.value = 1
        await RisingEdge(dut.clk)
        
    dut.pixel_valid.value = 0
    dut.calculate.value = 1
    await RisingEdge(dut.clk)
    dut.calculate.value = 0
    
    await with_timeout(RisingEdge(dut.com_valid), 10000, "ns")
    assert dut.com_x.value.integer == 50
    assert dut.com_y.value.integer == 60
    
    # wait a few cycles between frames
    await ClockCycles(dut.clk, 10)
    
    # frame 2
    for _ in range(200):
        dut.pixel_x.value = 100
        dut.pixel_y.value = 200
        dut.pixel_valid.value = 1
        await RisingEdge(dut.clk)
        
    dut.pixel_valid.value = 0
    dut.calculate.value = 1
    await RisingEdge(dut.clk)
    dut.calculate.value = 0
    
    await with_timeout(RisingEdge(dut.com_valid), 10000, "ns")
    assert dut.com_x.value.integer == 100
    assert dut.com_y.value.integer == 200

@cocotb.test()
async def test_single_pixel(dut):
    # system works properly with as little as one valid pixel
    dut._log.info("Starting test_single_pixel...")
    cocotb.start_soon(Clock(dut.clk, 13.468, units="ns").start())
    await reset_dut(dut)
    
    dut.pixel_x.value = 42
    dut.pixel_y.value = 84
    dut.pixel_valid.value = 1
    await RisingEdge(dut.clk)
    
    dut.pixel_valid.value = 0
    dut.calculate.value = 1
    await RisingEdge(dut.clk)
    dut.calculate.value = 0
    
    await with_timeout(RisingEdge(dut.com_valid), 10000, "ns")
    assert dut.com_x.value.integer == 42
    assert dut.com_y.value.integer == 84

@cocotb.test()
async def test_no_valid_pixels(dut):
    # no valid pixels, never fire
    dut._log.info("Starting test_no_valid_pixels...")
    cocotb.start_soon(Clock(dut.clk, 13.468, units="ns").start())
    await reset_dut(dut)
    
    # Trigger calculate immediately
    dut.calculate.value = 1
    await RisingEdge(dut.clk)
    dut.calculate.value = 0
    
    try:
        await with_timeout(RisingEdge(dut.com_valid), 2000, "ns")
        assert False, "com_valid asserted incorrectly when 0 pixels were provided."
    except SimTimeoutError:
        dut._log.info("Successfully timed out waiting for com_valid (Expected behavior).")

@cocotb.test()
async def test_max_pixels(dut):
    # no overflow
    dut._log.info("Starting test_max_pixels...")
    cocotb.start_soon(Clock(dut.clk, 13.468, units="ns").start())
    await reset_dut(dut)
    
    # 320 * 180 = 57,600 valid pixels
    for y in range(180):
        for x in range(320):
            dut.pixel_x.value = x
            dut.pixel_y.value = y
            dut.pixel_valid.value = 1
            await RisingEdge(dut.clk)
            
    dut.pixel_valid.value = 0
    dut.calculate.value = 1
    await RisingEdge(dut.clk)
    dut.calculate.value = 0
    
    await with_timeout(RisingEdge(dut.com_valid), 20000, "ns")
    
    assert dut.com_x.value.integer == 159, f"Expected 159, got {dut.com_x.value.integer}"
    assert dut.com_y.value.integer == 89, f"Expected 89, got {dut.com_y.value.integer}"


def com_runner():
    """Simulate the center_of_mass using the Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    
    # center_of_mass.sv instantiates divider.sv, both must be included
    sources = [
        proj_path / "hdl" / "divider.sv",
        proj_path / "hdl" / "center_of_mass.sv"
    ] 
    build_test_args = ["-Wall"]
    
    sys.path.append(str(proj_path / "sim"))
    hdl_toplevel = "center_of_mass"
    runner = get_runner(sim)
    
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        always=True,
        build_args=build_test_args,
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
    com_runner()