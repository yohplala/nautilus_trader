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

import orjson

from libc.stdint cimport int64_t

from nautilus_trader.common.c_enums.component_state cimport ComponentState
from nautilus_trader.common.c_enums.component_state cimport ComponentStateParser
from nautilus_trader.core.correctness cimport Condition
from nautilus_trader.core.message cimport Event
from nautilus_trader.core.uuid cimport UUID4
from nautilus_trader.model.identifiers cimport ComponentId
from nautilus_trader.model.identifiers cimport TraderId

from nautilus_trader.serialization.json.default import Default


cdef class ComponentStateChanged(Event):
    """
    Represents an event which includes information on the state of a component.

    Parameters
    ----------
    trader_id : TraderId
        The trader ID associated with the event.
    component_id : ComponentId
        The component ID associated with the event.
    component_type : str
        The component type.
    state : ComponentState
        The component state.
    event_id : UUID4
        The event ID.
    ts_event : int64
        The UNIX timestamp (nanoseconds) when the component state event occurred.
    ts_init : int64
        The UNIX timestamp (nanoseconds) when the object was initialized.
    """

    def __init__(
        self,
        TraderId trader_id not None,
        ComponentId component_id not None,
        str component_type not None,
        ComponentState state,
        dict config not None,
        UUID4 event_id not None,
        int64_t ts_event,
        int64_t ts_init,
    ):
        super().__init__(event_id, ts_event, ts_init)

        self.trader_id = trader_id
        self.component_id = component_id
        self.component_type = component_type
        self.state = state
        self.config = config

    def __str__(self) -> str:
        return (f"{type(self).__name__}("
                f"trader_id={self.trader_id.value}, "
                f"component_id={self.component_id}, "
                f"component_type={self.component_type}, "
                f"state={ComponentStateParser.to_str(self.state)}, "
                f"config={self.config}, "
                f"event_id={self.id})")

    def __repr__(self) -> str:
        return (f"{type(self).__name__}("
                f"trader_id={self.trader_id.value}, "
                f"component_id={self.component_id}, "
                f"component_type={self.component_type}, "
                f"state={ComponentStateParser.to_str(self.state)}, "
                f"config={self.config}, "
                f"event_id={self.id}, "
                f"ts_init={self.ts_init})")

    @staticmethod
    cdef ComponentStateChanged from_dict_c(dict values):
        Condition.not_none(values, "values")
        return ComponentStateChanged(
            trader_id=TraderId(values["trader_id"]),
            component_id=ComponentId(values["component_id"]),
            component_type=values["component_type"],
            state=ComponentStateParser.from_str(values["state"]),
            config=orjson.loads(values["config"]),
            event_id=UUID4(values["event_id"]),
            ts_event=values["ts_event"],
            ts_init=values["ts_init"],
        )

    @staticmethod
    cdef dict to_dict_c(ComponentStateChanged obj):
        Condition.not_none(obj, "obj")
        return {
            "type": "ComponentStateChanged",
            "trader_id": obj.trader_id.value,
            "component_id": obj.component_id.value,
            "component_type": obj.component_type,
            "state": ComponentStateParser.to_str(obj.state),
            "config": orjson.dumps(obj.config, default=Default.serialize),
            "event_id": obj.id.value,
            "ts_event": obj.ts_event,
            "ts_init": obj.ts_init,
        }

    @staticmethod
    def from_dict(dict values) -> ComponentStateChanged:
        """
        Return a component state changed event from the given dict values.

        Parameters
        ----------
        values : dict[str, object]
            The values for initialization.

        Returns
        -------
        ComponentStateChanged

        """
        return ComponentStateChanged.from_dict_c(values)

    @staticmethod
    def to_dict(ComponentStateChanged obj):
        """
        Return a dictionary representation of this object.

        Returns
        -------
        dict[str, object]

        """
        return ComponentStateChanged.to_dict_c(obj)
