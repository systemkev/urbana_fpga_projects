# FPGA Video Processing & Hardware Game Engine

![SystemVerilog](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Xilinx_Vivado-orange.svg)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen.svg)

This is a SystemVerilog FPGA project I put together that handles a real-time computer vision pipeline, drives an HDMI display, captures audio, and runs a hardware-accelerated game engine. It hooks up directly to an OV5640 camera, pulls in the pixel data, converts RGB to YCrCb, thresholds specific colors, and calculates a target's center of mass—all on the fly. 

Everything is heavily pipelined to hit 720p at 60FPS. I also threw in a pure-hardware version of Pong and wrote custom SPI/UART interfaces to stream data.

## Under the Hood

Instead of relying on black-box IP cores, I wrote custom state machines and pipelined datapaths for almost everything. 

### Vision Pipeline
* **`center_of_mass.sv` & `divider.sv`:** Hardware division eats up a ton of resources, so I built a custom sequential shift-and-subtract divider paired with an accumulator FSM. It processes pixels on the fly, meaning there is zero CPU overhead for object tracking.
* **`rgb_to_ycrcb.sv`:** Doing object tracking on raw RGB is notoriously unreliable. This is a 3-cycle pipelined color space converter that uses fractional fixed-point arithmetic (`N.M` format) to split the feed into luminance and chroma channels, which makes the tracking much more robust.
* **`pixel_reconstruct.sv`:** This handles the clock domain crossing between the camera's `PCLK` and the main system clock. It pieces together sequential 8-bit camera outputs into 16-bit RGB565 pixels while managing the horizontal and vertical sync signals.

### Custom HDMI (TMDS) Controller
* **`tmds_encoder.sv`:** I wrote a TMDS (Transition Minimized Differential Signaling) encoder from scratch. It handles DC-balancing to cut down on electromagnetic interference by keeping a running tally of 1s and 0s (disparity) and selectively inverting bits to maintain that balance.
* **`tmds_serializer.sv`:** Takes the 10-bit parallel TMDS data and pushes it out to the physical HDMI pins. It uses Xilinx `OSERDESE2` primitives for the high-speed serial stream (DDR), clocked at 5x the pixel clock.

### Hardware Game Engine (Pong)
* **`pong.sv`:** A pure hardware implementation of Pong. It manages bounding boxes, collision detection, and paddle physics based directly on the button inputs.
* **`lfsr_16.sv` / `lfsr_4.sv`:** Linear Feedback Shift Registers acting as a hardware RNG. I use these to randomize starting vectors and make the puck bounces genuinely unpredictable.
* **`image_sprite_2.sv`:** A memory-mapped sprite renderer that reads image and color palette data from BRAM. I delayed its output by exactly 4 clock cycles so it stays perfectly aligned with the rest of the video pipeline timing.

### Custom SPI and UART
* **`spi_con.sv`:** A custom SPI controller state machine managing `dclk`, `cs`, `copi`, and `cipo`. It grabs 17-bit data frames from an external MCP3008 ADC.
* **`uart_transmit.sv` & `uart_receive.sv`:** Serial TX/RX modules that use a fractional clock accumulator to hit specific baud rates (like 230,400 baud) derived straight from the 100MHz system clock.

---

## Pipeline Sync & Architecture

Pushing 720p at 60fps requires a tight 74.25 MHz pixel clock. Because different pieces of the pipeline (color space conversion, sprite rendering, crosshairs) take different amounts of clock cycles to compute, I had to implement deep shift-register pipelines (`h_count_pipe`, `v_count_pipe`, `active_draw_pipe`). 

By the time the center of mass calculation finishes, the background pixels and sync signals have been delayed by the exact amount needed (up to 8 cycles). `video_mux.sv` then generates the composite image, and because of the delay matching, everything aligns without tearing.

To handle the clock differences between the 50MHz camera feed (30FPS) and the 74.25MHz HDMI output (60FPS), I used `xilinx_true_dual_port_read_first_2_clock_ram` to create a frame buffer that safely crosses the clock domains.

---

## Hardware & Setup

* **Board:** Xilinx 7-Series FPGA (e.g., Arty S7 / Nexys A7 or any similar 100MHz board)
* **Peripherals:** 
  * OV5640 Camera module
  * MCP3008 ADC (for Microphone/Analog input)
  * VGA/HDMI output port
* **Software:** Xilinx Vivado

## Building the Project

1. Open Vivado and spin up a new RTL Project.
2. Drop all the `.sv` and `.v` files into your Design Sources.
3. Add your board's specific `.xdc` constraints file.
4. **Important:** Make sure the Memory Initialization Files (`rom.mem` for the camera registers, `image.mem`, `palette.mem`, etc.) are in a directory your synth directives can actually see.
5. Generate the bitstream and flash the FPGA.

## Controls Mapping

* **Switches [1:0]:** Test Pattern Generator (Solid, Horizontal, Vertical, Checkered)
* **Switches [3:1]:** Color Channel mask select (Red, Green, Blue, Luma, Chroma)
* **Switches [5:4]:** Video Background Multiplexer (Camera out, Grayscale, B/W mask, Chroma mask)
* **Switches [7:6]:** Video Target Multiplexer (None, Crosshair at Center of Mass, Sprite at Center of Mass)
* **Buttons [3:2]:** Move Paddle (Pong)
* **Button [0]:** Global System Reset