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

import unittest

from nautilus_trader.common.clock import TestClock
from nautilus_trader.common.factories import OrderFactory
from nautilus_trader.common.logging import TestLogger
from nautilus_trader.common.uuid import UUIDFactory
from nautilus_trader.execution.database import BypassExecutionDatabase
from nautilus_trader.execution.database import ExecutionDatabase
from nautilus_trader.model.identifiers import StrategyId
from nautilus_trader.model.identifiers import TraderId
from tests.test_kit.stubs import TestStubs

AUDUSD_SIM = TestStubs.security_audusd()
GBPUSD_SIM = TestStubs.security_gbpusd()


class ExecutionDatabaseTests(unittest.TestCase):

    def setUp(self):
        # Fixture Setup
        self.clock = TestClock()
        self.uuid_factory = UUIDFactory()
        self.logger = TestLogger(self.clock)

        self.trader_id = TraderId("TESTER", "000")
        self.account_id = TestStubs.account_id()

        self.order_factory = OrderFactory(
            trader_id=self.trader_id,
            strategy_id=StrategyId("S", "001"),
            clock=TestClock(),
        )

        self.database = ExecutionDatabase(trader_id=self.trader_id, logger=self.logger)

    def test_flush_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.flush)

    def test_load_accounts_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.load_accounts)

    def test_load_orders_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.load_orders)

    def test_load_positions_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.load_positions)

    def test_load_account_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.load_account, None)

    def test_load_order_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.load_order, None)

    def test_load_position_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.load_position, None)

    def test_load_strategy_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.load_strategy, None)

    def test_delete_strategy_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.delete_strategy, None)

    def test_add_account_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.add_account, None)

    def test_add_order_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.add_order, None)

    def test_add_position_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.add_position, None)

    def test_update_account_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.update_account, None)

    def test_update_order_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.update_order, None)

    def test_update_position_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.update_position, None)

    def test_update_strategy_when_not_implemented_raises_exception(self):
        self.assertRaises(NotImplementedError, self.database.update_strategy, None)


class BypassExecutionDatabaseTests(unittest.TestCase):

    def setUp(self):
        # Fixture Setup
        self.clock = TestClock()
        self.uuid_factory = UUIDFactory()
        self.logger = TestLogger(self.clock)

        self.trader_id = TraderId("TESTER", "000")
        self.account_id = TestStubs.account_id()

        self.order_factory = OrderFactory(
            trader_id=self.trader_id,
            strategy_id=StrategyId("S", "001"),
            clock=TestClock(),
        )

        self.database = BypassExecutionDatabase(trader_id=self.trader_id, logger=self.logger)

    def test_load_account_returns_none(self):
        self.assertIsNone(self.database.load_account(None))

    def test_load_order_returns_none(self):
        self.assertIsNone(self.database.load_order(None))

    def test_load_position_returns_none(self):
        self.assertIsNone(self.database.load_position(None))

    def test_load_strategy_returns_empty_dict(self):
        self.assertEqual({}, self.database.load_strategy(None))
