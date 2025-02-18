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


cdef class BookTypeParser:

    @staticmethod
    cdef str to_str(int value):
        if value == 1:
            return "L1_TBBO"
        elif value == 2:
            return "L2_MBP"
        elif value == 3:
            return "L3_MBO"
        else:
            raise ValueError(f"value was invalid, was {value}")

    @staticmethod
    cdef BookType from_str(str value) except *:
        if value == "L1_TBBO":
            return BookType.L1_TBBO
        elif value == "L2_MBP":
            return BookType.L2_MBP
        elif value == "L3_MBO":
            return BookType.L3_MBO
        else:
            raise ValueError(f"value was invalid, was {value}")

    @staticmethod
    def to_str_py(int value):
        return BookTypeParser.to_str(value)

    @staticmethod
    def from_str_py(str value):
        return BookTypeParser.from_str(value)
