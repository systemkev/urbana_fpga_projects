import os
import sys
from pathlib import Path

import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge, with_timeout
from cocotb.clock import Clock
from cocotb_tools.runner import get_runner

test_file = Path(__file__).stem

async def reset_dut(reset_wire, clock_wire, duration_cycles):
    reset_wire.value = 1
    for _ in range(duration_cycles):
        await RisingEdge(clock_wire)
    reset_wire.value = 0
    await RisingEdge(clock_wire)

@cocotb.test()
async def test_spi_transaction(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start()) 

    dut.trigger.value = 0
    dut.data_in.value = 0
    dut.cipo.value = 0
    
    await reset_dut(dut.rst, dut.clk, 5)

    tx_data = 0b10101010
    rx_data = 0b00110011
    data_width = 8

    await RisingEdge(dut.clk)
    dut.data_in.value = tx_data
    dut.trigger.value = 1
    
    await RisingEdge(dut.clk)
    dut.trigger.value = 0 

    await with_timeout(FallingEdge(dut.cs), 2000, 'ns')

    for i in range(data_width):
        current_rx_bit = (rx_data >> (data_width - 1 - i)) & 1
        dut.cipo.value = current_rx_bit

        await with_timeout(RisingEdge(dut.dclk), 2000, 'ns')
        
        expected_tx_bit = (tx_data >> (data_width - 1 - i)) & 1
        assert dut.copi.value == expected_tx_bit, f"COPI mismatch at bit {i}: Expected {expected_tx_bit}, got {dut.copi.value}"

        await with_timeout(FallingEdge(dut.dclk), 2000, 'ns')

    await with_timeout(RisingEdge(dut.cs), 2000, 'ns')

    await with_timeout(RisingEdge(dut.data_valid), 2000, 'ns')

    actual_out = dut.data_out.value.binstr
    expected_out = format(rx_data, f'0{data_width}b')
    
    await Timer(150, unit="ns")

def run_sim():
    sim = os.getenv("SIM", "icarus")
    
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim"))
    
    hdl_toplevel = "spi_con"
    sources = [proj_path / "hdl" / f"{hdl_toplevel}.sv"] 
    parameters = {}
    build_test_args = ["-Wall"]

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns','1ps'),
        waves=True
    )
    
    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module=test_file,
        waves=True
    )

if __name__ == "__main__":
    run_sim()