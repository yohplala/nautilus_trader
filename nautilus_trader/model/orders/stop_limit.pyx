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

from cpython.datetime cimport datetime
from libc.stdint cimport int64_t

from nautilus_trader.core.correctness cimport Condition
from nautilus_trader.core.datetime cimport maybe_unix_nanos_to_dt
from nautilus_trader.core.uuid cimport UUID4
from nautilus_trader.model.c_enums.contingency_type cimport ContingencyType
from nautilus_trader.model.c_enums.contingency_type cimport ContingencyTypeParser
from nautilus_trader.model.c_enums.liquidity_side cimport LiquiditySideParser
from nautilus_trader.model.c_enums.order_side cimport OrderSide
from nautilus_trader.model.c_enums.order_side cimport OrderSideParser
from nautilus_trader.model.c_enums.order_type cimport OrderType
from nautilus_trader.model.c_enums.order_type cimport OrderTypeParser
from nautilus_trader.model.c_enums.time_in_force cimport TimeInForce
from nautilus_trader.model.c_enums.time_in_force cimport TimeInForceParser
from nautilus_trader.model.events.order cimport OrderInitialized
from nautilus_trader.model.events.order cimport OrderTriggered
from nautilus_trader.model.events.order cimport OrderUpdated
from nautilus_trader.model.identifiers cimport ClientOrderId
from nautilus_trader.model.identifiers cimport InstrumentId
from nautilus_trader.model.identifiers cimport OrderListId
from nautilus_trader.model.identifiers cimport StrategyId
from nautilus_trader.model.identifiers cimport TraderId
from nautilus_trader.model.objects cimport Price
from nautilus_trader.model.objects cimport Quantity
from nautilus_trader.model.orders.base cimport PassiveOrder


cdef class StopLimitOrder(PassiveOrder):
    """
    Represents a stop-limit order.

    A stop-limit order is an instruction to submit a buy or sell limit order
    when the user-specified stop trigger price is attained or penetrated. The
    order has two basic components: the stop price and the limit price. When a
    trade has occurred at or through the stop price, the order becomes
    executable and enters the market as a limit order, which is an order to buy
    or sell at a specified price or better.

    A stop-limit eliminates the price risk associated with a stop order where
    the execution price cannot be guaranteed, but exposes the trader to the
    risk that the order may never fill even if the stop price is reached. The
    trader could "miss the market" altogether.

    Parameters
    ----------
    trader_id : TraderId
        The trader ID associated with the order.
    strategy_id : StrategyId
        The strategy ID associated with the order.
    instrument_id : InstrumentId
        The order instrument ID.
    client_order_id : ClientOrderId
        The client order ID.
    order_side : OrderSide {``BUY``, ``SELL``}
        The order side.
    quantity : Quantity
        The order quantity (> 0).
    price : Price
        The order limit price.
    trigger : Price
        The order stop trigger price.
    time_in_force : TimeInForce
        The order time-in-force.
    expire_time : datetime, optional
        The order expiry time.
    init_id : UUID4
        The order initialization event ID.
    ts_init : int64
        The UNIX timestamp (nanoseconds) when the object was initialized.
    post_only : bool, optional
        If the `LIMIT` order will only provide liquidity (once triggered).
    reduce_only : bool, optional
        If the `LIMIT` order carries the 'reduce-only' execution instruction.
    display_qty : Quantity, optional
        The quantity of the `LIMIT` order to display on the public book (iceberg).
    order_list_id : OrderListId, optional
        The order list ID associated with the order.
    parent_order_id : ClientOrderId, optional
        The order parent client order ID.
    child_order_ids : list[ClientOrderId], optional
        The order child client order ID(s).
    contingency : ContingencyType
        The order contingency type.
    contingency_ids : list[ClientOrderId], optional
        The order contingency client order ID(s).
    tags : str, optional
        The custom user tags for the order. These are optional and can
        contain any arbitrary delimiter if required.

    Raises
    ------
    ValueError
        If `quantity` is not positive (> 0).
    ValueError
        If `time_in_force` is ``GTD`` and the expire_time is ``None``.
    ValueError
        If `display_qty` is negative (< 0) or greater than `quantity`.
    """

    def __init__(
        self,
        TraderId trader_id not None,
        StrategyId strategy_id not None,
        InstrumentId instrument_id not None,
        ClientOrderId client_order_id not None,
        OrderSide order_side,
        Quantity quantity not None,
        Price price not None,
        Price trigger not None,
        TimeInForce time_in_force,
        datetime expire_time,  # Can be None
        UUID4 init_id not None,
        int64_t ts_init,
        bint post_only=False,
        bint reduce_only=False,
        Quantity display_qty=None,
        OrderListId order_list_id=None,
        ClientOrderId parent_order_id=None,
        list child_order_ids=None,
        ContingencyType contingency=ContingencyType.NONE,
        list contingency_ids=None,
        str tags=None,
    ):
        Condition.true(display_qty is None or 0 <= display_qty <= quantity, "display_qty was negative or greater than order quantity")  # noqa
        super().__init__(
            trader_id=trader_id,
            strategy_id=strategy_id,
            instrument_id=instrument_id,
            client_order_id=client_order_id,
            order_side=order_side,
            order_type=OrderType.STOP_LIMIT,
            quantity=quantity,
            price=price,
            time_in_force=time_in_force,
            expire_time=expire_time,
            reduce_only=reduce_only,
            options={
                "trigger": str(trigger),
                "post_only": post_only,
                "display_qty": str(display_qty) if display_qty is not None else None,
            },
            order_list_id=order_list_id,
            parent_order_id=parent_order_id,
            child_order_ids=child_order_ids,
            contingency=contingency,
            contingency_ids=contingency_ids,
            tags=tags,
            init_id=init_id,
            ts_init=ts_init,
        )

        self.trigger = trigger
        self.is_triggered = False
        self.is_post_only = post_only
        self.display_qty = display_qty

    def __repr__(self) -> str:
        cdef str id_string = f", id={self.venue_order_id.value})" if self.venue_order_id is not None else ")"
        return (f"{type(self).__name__}("
                f"{self.info()}, "
                f"trigger={self.trigger}, "
                f"status={self._fsm.state_string_c()}, "
                f"client_order_id={self.client_order_id.value}"
                f"{id_string}")

    cpdef dict to_dict(self):
        """
        Return a dictionary representation of this object.

        Returns
        -------
        dict[str, object]

        """
        return {
            "trader_id": self.trader_id.value,
            "strategy_id": self.strategy_id.value,
            "instrument_id": self.instrument_id.value,
            "client_order_id": self.client_order_id.value,
            "venue_order_id": self.venue_order_id.value if self.venue_order_id else None,
            "position_id": self.position_id if self.position_id else None,
            "account_id": self.account_id.value if self.account_id else None,
            "execution_id": self.execution_id.value if self.execution_id else None,
            "type": OrderTypeParser.to_str(self.type),
            "side": OrderSideParser.to_str(self.side),
            "quantity": str(self.quantity),
            "trigger": str(self.trigger),
            "price": str(self.price),
            "liquidity_side": LiquiditySideParser.to_str(self.liquidity_side),
            "expire_time_ns": self.expire_time_ns,
            "time_in_force": TimeInForceParser.to_str(self.time_in_force),
            "filled_qty": str(self.filled_qty),
            "avg_px": str(self.avg_px) if self.avg_px else None,
            "slippage": str(self.slippage),
            "status": self._fsm.state_string_c(),
            "is_post_only": self.is_post_only,
            "is_reduce_only": self.is_reduce_only,
            "display_qty": str(self.display_qty) if self.display_qty is not None else None,
            "order_list_id": self.order_list_id,
            "parent_order_id": self.parent_order_id,
            "child_order_ids": ",".join([o.value for o in self.child_order_ids]) if self.child_order_ids is not None else None,  # noqa
            "contingency": ContingencyTypeParser.to_str(self.contingency),
            "contingency_ids": ",".join([o.value for o in self.contingency_ids]) if self.contingency_ids is not None else None,  # noqa
            "tags": self.tags,
            "ts_last": self.ts_last,
            "ts_init": self.ts_init,
        }

    @staticmethod
    cdef StopLimitOrder create(OrderInitialized init):
        """
        Return a stop-limit order from the given initialized event.

        Parameters
        ----------
        init : OrderInitialized
            The event to initialize with.

        Returns
        -------
        StopLimitOrder

        Raises
        ------
        ValueError
            If `init.type` is not equal to ``STOP_LIMIT``.

        """
        Condition.not_none(init, "init")
        Condition.equal(init.type, OrderType.STOP_LIMIT, "init.type", "OrderType")

        # Parse display quantity
        cdef str display_qty_str = init.options["display_qty"]
        cdef Quantity display_qty = None
        if display_qty_str is not None:
            display_qty = Quantity.from_str_c(display_qty_str)
        return StopLimitOrder(
            trader_id=init.trader_id,
            strategy_id=init.strategy_id,
            instrument_id=init.instrument_id,
            client_order_id=init.client_order_id,
            order_side=init.side,
            quantity=init.quantity,
            price=Price.from_str_c(init.options["price"]),
            trigger=Price.from_str_c(init.options["trigger"]),
            time_in_force=init.time_in_force,
            expire_time=maybe_unix_nanos_to_dt(init.options.get("expire_time")),
            init_id=init.id,
            ts_init=init.ts_init,
            post_only=init.options["post_only"],
            reduce_only=init.reduce_only,
            display_qty=display_qty,
            order_list_id=init.order_list_id,
            parent_order_id=init.parent_order_id,
            child_order_ids=init.child_order_ids,
            contingency=init.contingency,
            contingency_ids=init.contingency_ids,
            tags=init.tags,
        )

    cdef void _updated(self, OrderUpdated event) except *:
        self.venue_order_id = event.venue_order_id
        self.quantity = event.quantity
        if self.is_triggered:
            self.price = event.price
        else:
            self.trigger = event.price

    cdef void _triggered(self, OrderTriggered event) except *:
        self.is_triggered = True
