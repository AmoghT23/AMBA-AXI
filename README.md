# AMBA-AXI

AXI (Advanced eXtensible Interface) is a high-performance, point-to-point bus standard developed by ARM to connect processors and peripherals within a chip. It supports parallel data transfer, multiple outstanding transactions, and high-speed throughput.

AXI Features:

Variable address and data widths
Burst transfers
Advanced caching and out-of-order execution
Separate read and write data paths
AXI4-Lite, introduced in 2010, is a simplified version used for control and status registers of IP cores.
It supports only single 32-bit transfers (no bursts, caching, or variable bus widths).
Commonly used to connect FPGA IP blocks to ARM processors (e.g., in Xilinx Zynq devices).

AXI4-Lite Channel Structure
AXI uses five independent channels, each with its own READY/VALID handshake signals:
Read Address (AR)
Read Data (R)
Write Address (AW)
Write Data (W)
Write Response (B)

These channels operate independently, allowing simultaneous read and write operations.
READY = receiver is ready
VALID = sender has valid data
When both are high in the same clock cycle, the transfer occurs.

Write Transaction (Master → Slave)
Master sends address (AWADDR) and data (WDATA), asserts AWVALID and WVALID.
Slave asserts AWREADY and WREADY when ready.
When both VALID and READY are high → data is transferred.
Slave responds with BRESP = “00” (OK) and BVALID to confirm completion.

Read Transaction (Slave → Master)
Master sends read address (ARADDR), asserts ARVALID.
Slave asserts ARREADY to accept it.
Slave sends data (RDATA) with RVALID.
Master asserts RREADY to receive.
Slave sets RRESP = “00” (OK).

Handshake Benefits
READY/VALID signaling prevents bus stalls.
Each channel operates at its own pace, improving throughput and concurrency.
Read and write operations don’t block each other.

AXI Interconnect Core
When connecting an ARM (master) to an FPGA IP block (slave):
The AXI interconnect core automatically manages communication between AXI variants (AXI4, AXI4-Lite, AXI-Stream).
It handles data width conversion, burst handling, and multiple masters/slaves.
In a single-master/single-slave AXI4-Lite setup, it simplifies to direct wiring.

🧾 Signal Overview

~160 signals total in AXI4-Lite
128 for address/data
12 for protection/caching (usually off)
10 handshake (READY/VALID per channel)
8 misc (clock, reset, byte strobes, response codes)
