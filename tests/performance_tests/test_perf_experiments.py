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

from nautilus_trader.core.message import Message
from nautilus_trader.core.message import MessageCategory
from nautilus_trader.core.uuid import UUID4
from nautilus_trader.model.commands.trading import SubmitOrder
from tests.test_kit.performance import PerformanceHarness


MESSAGE = Message(MessageCategory.COMMAND, UUID4(), 0)


class Experiments:
    @staticmethod
    def class_name():
        x = "123".__class__.__name__
        return x

    @staticmethod
    def built_in_arithmetic():
        x = 1 + 1
        return x


class TestPerformanceExperiments(PerformanceHarness):
    @staticmethod
    def test_builtin_arithmetic(benchmark):
        benchmark.pedantic(
            target=Experiments.built_in_arithmetic,
            iterations=100_000,
            rounds=1,
        )
        # ~0.0ms / ~0.1μs / 106ns minimum of 100,000 runs @ 1 iteration each run.

    @staticmethod
    def test_class_name(benchmark):
        benchmark.pedantic(
            target=Experiments.class_name,
            iterations=100_000,
            rounds=1,
        )
        # ~0.0ms / ~0.2μs / 161ns minimum of 100,000 runs @ 1 iteration each run.

    @staticmethod
    def test_is_instance(benchmark):
        benchmark.pedantic(
            target=isinstance,
            args=(MESSAGE, SubmitOrder),
            iterations=100_000,
            rounds=1,
        )
        # ~0.0ms / ~0.2μs / 153ns minimum of 100,000 runs @ 1 iteration each run.

    @staticmethod
    def test_is_message_type(benchmark):
        benchmark.pedantic(
            target=MESSAGE.category.__eq__,
            args=(0,),
            iterations=100_000,
            rounds=1,
        )
        # ~0.0ms / ~0.2μs / 150ns minimum of 100,000 runs @ 1 iteration each run.
