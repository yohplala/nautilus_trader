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

from nautilus_trader.core.fsm cimport FiniteStateMachine
from nautilus_trader.core.uuid cimport UUID4
from nautilus_trader.model.c_enums.contingency_type cimport ContingencyType
from nautilus_trader.model.c_enums.liquidity_side cimport LiquiditySide
from nautilus_trader.model.c_enums.order_side cimport OrderSide
from nautilus_trader.model.c_enums.order_status cimport OrderStatus
from nautilus_trader.model.c_enums.order_type cimport OrderType
from nautilus_trader.model.c_enums.position_side cimport PositionSide
from nautilus_trader.model.c_enums.time_in_force cimport TimeInForce
from nautilus_trader.model.events.order cimport OrderAccepted
from nautilus_trader.model.events.order cimport OrderCanceled
from nautilus_trader.model.events.order cimport OrderDenied
from nautilus_trader.model.events.order cimport OrderEvent
from nautilus_trader.model.events.order cimport OrderExpired
from nautilus_trader.model.events.order cimport OrderFilled
from nautilus_trader.model.events.order cimport OrderInitialized
from nautilus_trader.model.events.order cimport OrderRejected
from nautilus_trader.model.events.order cimport OrderSubmitted
from nautilus_trader.model.events.order cimport OrderTriggered
from nautilus_trader.model.events.order cimport OrderUpdated
from nautilus_trader.model.identifiers cimport AccountId
from nautilus_trader.model.identifiers cimport ClientOrderId
from nautilus_trader.model.identifiers cimport ExecutionId
from nautilus_trader.model.identifiers cimport InstrumentId
from nautilus_trader.model.identifiers cimport OrderListId
from nautilus_trader.model.identifiers cimport PositionId
from nautilus_trader.model.identifiers cimport StrategyId
from nautilus_trader.model.identifiers cimport TraderId
from nautilus_trader.model.identifiers cimport VenueOrderId
from nautilus_trader.model.objects cimport Price
from nautilus_trader.model.objects cimport Quantity


cdef class Order:
    cdef list _events
    cdef list _venue_order_ids
    cdef list _execution_ids
    cdef FiniteStateMachine _fsm
    cdef OrderStatus _rollback_status

    cdef readonly TraderId trader_id
    """The trader ID associated with the position.\n\n:returns: `TraderId`"""
    cdef readonly StrategyId strategy_id
    """The strategy ID associated with the order.\n\n:returns: `StrategyId`"""
    cdef readonly InstrumentId instrument_id
    """The order instrument ID.\n\n:returns: `InstrumentId`"""
    cdef readonly ClientOrderId client_order_id
    """The client order ID.\n\n:returns: `ClientOrderId`"""
    cdef readonly VenueOrderId venue_order_id
    """The venue assigned order ID.\n\n:returns: `VenueOrderId`"""
    cdef readonly PositionId position_id
    """The position ID associated with the order.\n\n:returns: `PositionId`"""
    cdef readonly AccountId account_id
    """The account ID associated with the order.\n\n:returns: `AccountId` or ``None``"""
    cdef readonly ExecutionId execution_id
    """The orders last execution ID.\n\n:returns: `ExecutionId` or ``None``"""
    cdef readonly OrderSide side
    """The order side.\n\n:returns: `OrderSide`"""
    cdef readonly OrderType type
    """The order type.\n\n:returns: `OrderType`"""
    cdef readonly TimeInForce time_in_force
    """The order time-in-force.\n\n:returns: `TimeInForce`"""
    cdef readonly bint is_reduce_only
    """If the order carries the 'reduce-only' execution instruction.\n\n:returns: `bool`"""
    cdef readonly Quantity quantity
    """The order quantity.\n\n:returns: `Quantity`"""
    cdef readonly Quantity filled_qty
    """The order total filled quantity.\n\n:returns: `Quantity`"""
    cdef readonly Quantity leaves_qty
    """The order total leaves quantity.\n\n:returns: `Quantity`"""
    cdef readonly object avg_px
    """The order average fill price.\n\n:returns: `Decimal` or ``None``"""
    cdef readonly object slippage
    """The order total price slippage.\n\n:returns: `Decimal`"""
    cdef readonly OrderListId order_list_id
    """The order list ID associated with the order.\n\n:returns: `OrderListId` or ``None``"""
    cdef readonly ClientOrderId parent_order_id
    """The parent client order ID.\n\n:returns: `ClientOrderId` or ``None``"""
    cdef readonly list child_order_ids
    """The child order ID(s).\n\n:returns: `list[ClientOrderId]` or ``None``"""
    cdef readonly ContingencyType contingency
    """The orders contingency type.\n\n:returns: `ContingencyType`"""
    cdef readonly list contingency_ids
    """The orders contingency client order ID(s).\n\n:returns: `list[ClientOrderId]` or ``None``"""
    cdef readonly str tags
    """The order custom user tags.\n\n:returns: `str` or ``None``"""
    cdef readonly UUID4 init_id
    """The event ID of the `OrderInitialized` event.\n\n:returns: `UUID4`"""
    cdef readonly int64_t ts_last
    """The UNIX timestamp (nanoseconds) when the last fill occurred (0 for no fill).\n\n:returns: `int64`"""
    cdef readonly int64_t ts_init
    """The UNIX timestamp (nanoseconds) when the object was initialized.\n\n:returns: `int64`"""

    cpdef str info(self)
    cpdef dict to_dict(self)

    cdef OrderStatus status_c(self) except *
    cdef OrderInitialized init_event_c(self)
    cdef OrderEvent last_event_c(self)
    cdef list events_c(self)
    cdef list execution_ids_c(self)
    cdef int event_count_c(self) except *
    cdef str status_string_c(self)
    cdef str type_string_c(self)
    cdef str side_string_c(self)
    cdef str tif_string_c(self)
    cdef bint is_buy_c(self) except *
    cdef bint is_sell_c(self) except *
    cdef bint is_passive_c(self) except *
    cdef bint is_aggressive_c(self) except *
    cdef bint is_contingency_c(self) except *
    cdef bint is_parent_order_c(self) except *
    cdef bint is_child_order_c(self) except *
    cdef bint is_active_c(self) except *
    cdef bint is_inflight_c(self) except *
    cdef bint is_working_c(self) except *
    cdef bint is_pending_update_c(self) except *
    cdef bint is_pending_cancel_c(self) except *
    cdef bint is_completed_c(self) except *

    @staticmethod
    cdef OrderSide opposite_side_c(OrderSide side) except *

    @staticmethod
    cdef OrderSide flatten_side_c(PositionSide side) except *

    cpdef void apply(self, OrderEvent event) except *

    cdef void _denied(self, OrderDenied event) except *
    cdef void _submitted(self, OrderSubmitted event) except *
    cdef void _rejected(self, OrderRejected event) except *
    cdef void _accepted(self, OrderAccepted event) except *
    cdef void _updated(self, OrderUpdated event) except *
    cdef void _canceled(self, OrderCanceled event) except *
    cdef void _expired(self, OrderExpired event) except *
    cdef void _triggered(self, OrderTriggered event) except *
    cdef void _filled(self, OrderFilled event) except *
    cdef object _calculate_avg_px(self, Quantity last_qty, Price last_px)


cdef class PassiveOrder(Order):
    cdef readonly Price price
    """The order price (STOP or LIMIT).\n\n:returns: `Price`"""
    cdef readonly LiquiditySide liquidity_side
    """The order liquidity side.\n\n:returns: `LiquiditySide`"""
    cdef readonly datetime expire_time
    """The order expire time.\n\n:returns: `datetime` or ``None``"""
    cdef readonly int64_t expire_time_ns
    """The order expire time (nanoseconds), zero for no expire time.\n\n:returns: `int64`"""

    cpdef dict to_dict(self)

    cdef list venue_order_ids_c(self)

    cdef void _set_slippage(self) except *
