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

import asyncio

import pytest

from nautilus_trader.adapters.ftx.http.client import FTXHttpClient
from nautilus_trader.common.clock import LiveClock
from nautilus_trader.common.logging import Logger


@pytest.fixture(scope="session")
def loop():
    return asyncio.get_event_loop()


@pytest.fixture(scope="session")
def live_clock():
    return LiveClock()


@pytest.fixture(scope="session")
def live_logger(live_clock):
    return Logger(clock=live_clock)


@pytest.fixture(scope="session")
def ftx_http_client(loop, live_clock, live_logger):
    client = FTXHttpClient(  # noqa: S106 (no hardcoded password)
        loop=asyncio.get_event_loop(),
        clock=live_clock,
        logger=live_logger,
        key="SOME_FTX_API_KEY",
        secret="SOME_FTX_API_SECRET",
    )
    return client
