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

from nautilus_trader.core.data cimport Data


cdef class DataType:
    """
    Represents a data type including metadata.

    Parameters
    ----------
    type : type
        The ``Data`` type of the data.
    metadata : dict
        The data types metadata.

    Raises
    ------
    TypeError
        If `metadata` contains a key or value which is not hashable.

    Warnings
    --------
    This class may be used as a key in hash maps throughout the system, thus
    the key and value contents of metadata must themselves be hashable.
    """

    def __init__(self, type type not None, dict metadata=None):    # noqa (shadows built-in type)
        if metadata is None:
            metadata = {}

        self._key = frozenset(metadata.items())
        self._hash = hash((self.type, self._key))  # Assign hash for improved time complexity
        self.type = type
        self.metadata = metadata

    def __eq__(self, DataType other) -> bool:
        return self.type == other.type and self._key == other._key  # noqa

    def __hash__(self) -> int:
        return self._hash

    def __str__(self) -> str:
        return f"<{self.type.__name__}> {self.metadata}"

    def __repr__(self) -> str:
        return f"{type(self).__name__}(type={self.type.__name__}, metadata={self.metadata})"


cdef class GenericData(Data):
    """
    Provides a generic data wrapper which includes data type information.

    Parameters
    ----------
    data_type : DataType
        The data type.
    data : Data
        The data object to wrap.
    """

    def __init__(
        self,
        DataType data_type not None,
        Data data not None,
    ):
        super().__init__(data.ts_event, data.ts_init)
        self.data_type = data_type
        self.data = data
