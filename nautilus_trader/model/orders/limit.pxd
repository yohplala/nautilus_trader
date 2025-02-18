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

from nautilus_trader.model.events.order cimport OrderInitialized
from nautilus_trader.model.objects cimport Quantity
from nautilus_trader.model.orders.base cimport PassiveOrder


cdef class LimitOrder(PassiveOrder):
    cdef readonly bint is_post_only
    """If the order will only provide liquidity (make a market).\n\n:returns: `bool`"""
    cdef readonly Quantity display_qty
    """The quantity of the order to display on the public book (iceberg).\n\n:returns: `Quantity` or ``None``"""

    @staticmethod
    cdef LimitOrder create(OrderInitialized init)
