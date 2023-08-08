# Copyright Antmicro 2023
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import RisingEdge, Event, Lock
from cocotb.queue import Queue

import logging
from enum import Enum

# ==============================================================================


class ReqOpcode(Enum):
    """
    TileLink request (A-channel) opcodes
    """
    Get             = 0x4
    PutFullData     = 0x0
    PutPartialData  = 0x1

class RspOpcode(Enum):
    """
    TileLink response (D-channel) opcodes
    """
    AccessAck       = 0x0
    AccessAckData   = 0x1

# ==============================================================================


class MasterInterface:
    """
    TileLink UL Master (host) Interface
    """

    SIGNALS = {
        "clk",
        "rst_n",

        "a_ready",
        "a_valid",
        "a_opcode",
        "a_source",
        "a_address",
        "a_size",
        "a_mask",
        "a_data",

        "d_ready",
        "d_valid",
        "d_opcode",
        "d_source",
        "d_sink",
        "d_size",
        "d_data",
        "d_error",
    }

    class Transfer:
        def __init__(self, opcode, address, source_id):
            self.opcode    = opcode
            self.address   = address,
            self.source_id = source_id
            self.event     = Event()

    def __init__(self, signals, max_pending=4):

        # Check if we have all signals
        missing = False
        for name in self.SIGNALS:
            if name not in signals:
                logging.critical("missing '{}'".format(name))
                missing = True

        assert missing is False

        self.signals = signals
        self.max_pending = max_pending
        self.pending = dict()
        self.r_queue = Queue()

        self.lock    = Lock()
        self.next_id = 0

    def start(self):
        """
        Starts the interface
        """
        cocotb.fork(self.process())

    async def _transfer(self, opcode, address=None, data=None, mask=None):
        """
        Issues a TileLink UL transfer and enqueues it so that the response
        can be properly interpreted
        """

        # Wait for the pending transfer for the next slot
        async with self.lock:
            transfer = self.signals.get(self.next_id, None)
        if transfer:
            await transfer.event.wait()

        # Assert valid + data
        await RisingEdge(self.signals["clk"])

        self.signals["a_valid"].value   = 1
        self.signals["a_opcode"].value  = opcode.value
        self.signals["a_source"].value  = self.next_id
        self.signals["a_size"].value    = 2

        if address is not None:
            self.signals["a_address"].value = address
        if data is not None:
            self.signals["a_data"].value = data
        if mask is not None:
            self.signals["a_mask"].value = mask

        # Wait for ready
        for i in range(100): # FIXME: Arbitrary
            await RisingEdge(self.signals["clk"])
            if self.signals["a_ready"].value:
                break
        else:
            assert False, "TileLink A timeout"

        # Deassert valid
        self.signals["a_valid"].value = 0

        # Store the pending transfer
        async with self.lock:
            self.pending[self.next_id] = self.Transfer(
                opcode, address, self.next_id)

        # Next source id
        self.next_id = (self.next_id + 1) % self.max_pending

    async def get(self, address):
        """
        Issues a TileLink UL Get request. DOES NOT WAIT FOR THE DATA
        """
        opcode = ReqOpcode.Get
        await self._transfer(opcode, address)

    async def put_full_data(self, address, data):
        """
        Issues a TileLink UL PutFullData request
        """
        opcode = ReqOpcode.PutFullData
        await self._transfer(opcode, address, data, 0xF)

    async def process(self):
        """
        A worker task function, serves TileLink responses.
        """

        # Always accept responses
        self.signals["d_ready"].value = 1

        # Handle TileLink D channel responses
        while True:
            await RisingEdge(self.signals["clk"])

            # Got a valid response
            if self.signals["d_valid"].value and self.signals["d_ready"].value:
                source_id = int(self.signals["d_source"].value)
                opcode    = RspOpcode(self.signals["d_opcode"].value)

                async with self.lock:

                    # Get the transfer object
                    assert source_id in self.pending, source_id
                    transfer = self.pending[source_id]

                    # AccessAck
                    if opcode == RspOpcode.AccessAck:
                        assert transfer.opcode in [ReqOpcode.PutFullData,
                                                   ReqOpcode.PutPartialData]

                    # AccessAckData
                    elif opcode == RspOpcode.AccessAckData:
                        assert transfer.opcode in [ReqOpcode.Get]

                    # Unknown
                    else:
                        assert False, "Invalid opcode 0x{:01X}".format(
                            int(self.signals["d_opcode"].value)
                        )

                    # Put the reaponse to the queue. In case of an error put
                    # None
                    if self.signals["d_error"].value:
                        data = None
                    else:
                        data = int(self.signals["d_data"].value)
                    await self.r_queue.put((transfer.address, data))

                    # Signal the event and remove the pending transfer
                    transfer.event.set()
                    del self.pending[source_id]

# ==============================================================================


class SlaveInterface:
    """
    TileLink UL Slave (device) Interface.

    The interface listens to requests on A channel and issues responses through
    the B channel. 

    User must provide the tranfer_handler coroutine that is invoked for each
    received request. The coroutine should return a data word or None to
    indicate an error. Each response is handled by a different thread so the
    coroutine can await something.
    """

    SIGNALS = {
        "clk",
        "rst_n",

        "a_ready",
        "a_valid",
        "a_opcode",
        "a_source",
        "a_address",
        "a_size",
        "a_mask",
        "a_data",

        "d_ready",
        "d_valid",
        "d_opcode",
        "d_source",
        "d_sink",
        "d_size",
        "d_data",
        "d_error",
    }

    def __init__(self, name, signals, logger):

        # Logger
        if not logger:
            logger = logging.getLogger()
        self.logger = logger
        self.name   = "TLUL.S[{}]".format(name)

        # Check if we have all signals
        missing = False
        for sig in self.SIGNALS:
            if sig not in signals:
                self.logger.critical(self.name + " missing '{}'".format(sig))
                missing = True

        assert missing is False

        self.signals = signals

        # No handler by default
        self.transfer_handler = None

    def start(self):
        """
        Starts the interface
        """
        cocotb.fork(self.process())

    async def process(self):
        """
        A worker task function, serves TileLink requests.
        """

        # Always accept requests
        self.signals["a_ready"].value = 1

        while True:

            # Handle reset
            if self.signals["rst_n"].value == 0:
                self.logger.info(self.name + " TLUL slave interface in reset")

                await RisingEdge(self.signals["rst_n"])
                self.signals["d_valid"].valid = 0

                self.logger.info(self.name + " TLUL slave interface brought out of reset")

            # Act on rising edge
            await RisingEdge(self.signals["clk"])

            # Check if we have a valid request
            if self.signals["a_valid"].value and self.signals["a_ready"].value:

                # Sample signals
                opcode    = int(self.signals["a_opcode"].value)
                address   = int(self.signals["a_address"].value)
                data      = int(self.signals["a_data"].value)
                mask      = int(self.signals["a_mask"].value)
                source_id = int(self.signals["a_source"].value)

                # Parse and validate opcode
                opcode = ReqOpcode(opcode)

                # Handle the request
                cocotb.fork(self.request_handler(
                    opcode, address, data, mask, source_id)
                )

    async def request_handler(self, opcode, address, wdata, wmask, source_id):
        """
        Request handler
        """

        self.logger.debug(
            self.name + " {} A:{:08X} D:{:08X} M:{:08X} id:{}".format(
                opcode, address, wdata, wmask, source_id)
        )

        # Handle the request. If no handler is provided respond with error
        if self.transfer_handler:
            rdata = self.transfer_handler(opcode, address, wdata, wmask)
        else:
            rdata = None

        # Send response
        await RisingEdge(self.signals["clk"])

        opcode_map = {
            ReqOpcode.Get:            RspOpcode.AccessAckData,
            ReqOpcode.PutFullData:    RspOpcode.AccessAck,
            ReqOpcode.PutPartialData: RspOpcode.AccessAck,
        }

        self.signals["d_valid"].value   = 1
        self.signals["d_opcode"].value  = opcode_map[opcode].value
        self.signals["d_size"].value    = 2
        self.signals["d_source"].value  = source_id
        self.signals["d_sink"].value    = 0
        self.signals["d_data"].value    = 0 if rdata is None else rdata
        self.signals["d_error"].value   = 1 if rdata is None else 0

        # Wait for ready
        for i in range(100): # FIXME: Arbitrary
            await RisingEdge(self.signals["clk"])
            if self.signals["d_ready"].value:
                break
        else:
            assert False, "TileLink D timeout"

        # Deassert valid
        self.signals["d_valid"].value = 0

