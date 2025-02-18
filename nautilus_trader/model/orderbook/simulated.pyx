# -------------------------------------------------------------------------------------------------
#  Copyright (C) 2015-2021 Nautech Systems Pty Ltd. All rights reserved.
#  https://nautechsystems.io
#
#  Licensed under the GNU Lesser General Public License Version 3.0 (the "License");
#  You may not use this file except in compliance with the License.
#  You may obtain a copy of the License at https://www.gnu.org/licenses/lgpl-3.0.en.html
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# -------------------------------------------------------------------------------------------------

from libc.stdint cimport uint8_t
from libc.stdint cimport uint64_t

from nautilus_trader.model.c_enums.aggressor_side cimport AggressorSide
from nautilus_trader.model.c_enums.order_side cimport OrderSide
from nautilus_trader.model.data.tick cimport QuoteTick
from nautilus_trader.model.data.tick cimport Tick
from nautilus_trader.model.data.tick cimport TradeTick
from nautilus_trader.model.identifiers cimport InstrumentId
from nautilus_trader.model.orderbook.book cimport L1OrderBook
from nautilus_trader.model.orderbook.book cimport L2OrderBook
from nautilus_trader.model.orderbook.book cimport L3OrderBook
from nautilus_trader.model.orderbook.data cimport Order


cdef class SimulatedL1OrderBook(L1OrderBook):
    """
    Provides a simulated level 1 order book for backtesting.

    Parameters
    ----------
    instrument_id : InstrumentId
        The instrument ID for the book.
    price_precision : uint8
        The price precision of the books orders.
    size_precision : uint8
        The size precision of the books orders.

    Raises
    ------
    OverflowError
        If `price_precision` is negative (< 0).
    OverflowError
        If `size_precision` is negative (< 0).
    """

    def __init__(
        self,
        InstrumentId instrument_id not None,
        uint8_t price_precision,
        uint8_t size_precision,
    ):
        super().__init__(
            instrument_id=instrument_id,
            price_precision=price_precision,
            size_precision=size_precision,
        )

        self._top_bid = None
        self._top_ask = None
        self._top_bid_level = None
        self._top_ask_level = None

    cpdef void add(self, Order order, uint64_t update_id=0) except *:
        """
        NotImplemented (Use `update(order)` for SimulatedOrderBook).
        """
        raise NotImplementedError("Use `update(order)` for L1OrderBook")  # pragma: no cover

    cpdef void update_tick(self, Tick tick) except *:
        """
        Update the order book with the given tick.

        Parameters
        ----------
        tick : Tick
            The tick to update with.

        """
        if isinstance(tick, QuoteTick):
            self._update_quote_tick(tick)
        elif isinstance(tick, TradeTick):
            self._update_trade_tick(tick)

    cdef void _update_quote_tick(self, QuoteTick tick):
        self._update_bid(tick.bid, tick.bid_size)
        self._update_ask(tick.ask, tick.ask_size)

    cdef void _update_trade_tick(self, TradeTick tick):
        if tick.aggressor_side == AggressorSide.SELL:  # TAKER hit the bid
            self._update_bid(tick.price, tick.size)
            if self._top_ask and self._top_bid.price >= self._top_ask.price:
                self._top_ask.price = self._top_bid.price
                self._top_ask_level.price = self._top_bid.price
        elif tick.aggressor_side == AggressorSide.BUY:  # TAKER lifted the offer
            self._update_ask(tick.price, tick.size)
            if self._top_bid and self._top_ask.price <= self._top_bid.price:
                self._top_bid.price = self._top_ask.price
                self._top_bid_level.price = self._top_ask.price

    cdef void _update_bid(self, double price, double size):
        cdef Order bid
        if self._top_bid is None:
            bid = self._process_order(Order(price, size, OrderSide.BUY))
            self._add(bid, update_id=0)
            self._top_bid = bid
            self._top_bid_level = self.bids.top()
        else:
            self._top_bid_level.price = price
            self._top_bid.update_price(price)
            self._top_bid.update_size(size)

    cdef void _update_ask(self, double price, double size):
        cdef Order ask
        if self._top_ask is None:
            ask = self._process_order(Order(price, size, OrderSide.SELL))
            self._add(ask, update_id=0)
            self._top_ask = ask
            self._top_ask_level = self.asks.top()
        else:
            self._top_ask_level.price = price
            self._top_ask.update_price(price)
            self._top_ask.update_size(size)


cdef class SimulatedL2OrderBook(L2OrderBook):
    """
    Provides a simulated level 2 order book for backtesting.

    Parameters
    ----------
    instrument_id : InstrumentId
        The instrument ID for the book.
    price_precision : uint8
        The price precision of the books orders.
    size_precision : uint8
        The size precision of the books orders.

    Raises
    ------
    OverflowError
        If `price_precision` is negative (< 0).
    OverflowError
        If `size_precision` is negative (< 0).
    """

    def __init__(
        self,
        InstrumentId instrument_id not None,
        uint8_t price_precision,
        uint8_t size_precision,
    ):
        super().__init__(
            instrument_id=instrument_id,
            price_precision=price_precision,
            size_precision=size_precision,
        )

        # Placeholder class for implementation


cdef class SimulatedL3OrderBook(L3OrderBook):
    """
    Provides a simulated level 3 order book for backtesting.

    Parameters
    ----------
    instrument_id : InstrumentId
        The instrument ID for the book.
    price_precision : uint8
        The price precision of the books orders.
    size_precision : uint8
        The size precision of the books orders.

    Raises
    ------
    OverflowError
        If `price_precision` is negative (< 0).
    OverflowError
        If `size_precision` is negative (< 0).
    """

    def __init__(
        self,
        InstrumentId instrument_id not None,
        uint8_t price_precision,
        uint8_t size_precision,
    ):
        super().__init__(
            instrument_id=instrument_id,
            price_precision=price_precision,
            size_precision=size_precision,
        )

        # Placeholder class for implementation
