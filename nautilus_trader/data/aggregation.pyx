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

from typing import Callable

from cpython.datetime cimport datetime
from cpython.datetime cimport timedelta
from libc.stdint cimport int64_t

from decimal import Decimal

from nautilus_trader.common.clock cimport Clock
from nautilus_trader.common.logging cimport Logger
from nautilus_trader.common.logging cimport LoggerAdapter
from nautilus_trader.common.timer cimport TestTimer
from nautilus_trader.common.timer cimport TimeEvent
from nautilus_trader.core.correctness cimport Condition
from nautilus_trader.core.datetime cimport secs_to_nanos
from nautilus_trader.model.c_enums.bar_aggregation cimport BarAggregation
from nautilus_trader.model.c_enums.bar_aggregation cimport BarAggregationParser
from nautilus_trader.model.c_enums.price_type cimport PriceType
from nautilus_trader.model.data.bar cimport Bar
from nautilus_trader.model.data.bar cimport BarType
from nautilus_trader.model.data.tick cimport QuoteTick
from nautilus_trader.model.data.tick cimport TradeTick
from nautilus_trader.model.instruments.base cimport Instrument
from nautilus_trader.model.objects cimport Price
from nautilus_trader.model.objects cimport Quantity


cdef class BarBuilder:
    """
    Provides a generic bar builder for aggregation.

    Parameters
    ----------
    instrument : Instrument
        The instrument for the builder.
    bar_type : BarType
        The bar type for the builder.

    Raises
    ------
    ValueError
        If `instrument.id` != `bar_type.instrument_id`.
    """

    def __init__(
        self,
        Instrument instrument not None,
        BarType bar_type not None,
    ):
        Condition.equal(instrument.id, bar_type.instrument_id, "instrument.id", "bar_type.instrument_id")

        self._bar_type = bar_type

        self.price_precision = instrument.price_precision
        self.size_precision = instrument.size_precision
        self.initialized = False
        self.ts_last = 0
        self.count = 0

        self._partial_set = False
        self._last_close = None
        self._open = None
        self._high = None
        self._low = None
        self._close = None
        self.volume = Decimal(0)

    def __repr__(self) -> str:
        return (f"{type(self).__name__}("
                f"{self._bar_type},"
                f"{self._open},"
                f"{self._high},"
                f"{self._low},"
                f"{self._close},"
                f"{self.volume})")

    cpdef void set_partial(self, Bar partial_bar) except *:
        """
        Set the initial values for a partially completed bar.

        This method can only be called once per instance.

        Parameters
        ----------
        partial_bar : Bar
            The partial bar with values to set.

        """
        if self._partial_set:
            return  # Already updated

        self._open = partial_bar.open

        if self._high is None or partial_bar.high > self._high:
            self._high = partial_bar.high

        if self._low is None or partial_bar.low < self._low:
            self._low = partial_bar.low

        if self._close is None:
            self._close = partial_bar.close

        self.volume += partial_bar.volume

        if self.ts_last == 0:
            self.ts_last = partial_bar.ts_init

        self._partial_set = True
        self.initialized = True

    cpdef void update(self, Price price, Quantity size, int64_t ts_event) except *:
        """
        Update the bar builder.

        Parameters
        ----------
        price : Price
            The update price.
        size : Decimal
            The update size.
        ts_event : int64
            The UNIX timestamp (nanoseconds) of the update.

        """
        Condition.not_none(price, "price")
        Condition.not_none(size, "size")

        # TODO: What happens if the first tick updates before a partial bar is applied?
        if ts_event < self.ts_last:
            return  # Not applicable

        if self._open is None:
            # Initialize builder
            self._open = price
            self._high = price
            self._low = price
            self.initialized = True
        elif price > self._high:
            self._high = price
        elif price < self._low:
            self._low = price

        self._close = price
        self.volume += size
        self.count += 1
        self.ts_last = ts_event

    cpdef void reset(self) except *:
        """
        Reset the bar builder.

        All stateful fields are reset to their initial value.
        """
        self._open = self._close
        self._high = self._close
        self._low = self._close

        self.volume = Decimal(0)
        self.count = 0

    cpdef Bar build_now(self):
        """
        Return the aggregated bar and reset.

        Returns
        -------
        Bar

        """
        return self.build(self.ts_last)

    cpdef Bar build(self, int64_t ts_event):
        """
        Return the aggregated bar with the given closing timestamp, and reset.

        Parameters
        ----------
        ts_event : int64
            The UNIX timestamp (nanoseconds) of the bar close.

        Returns
        -------
        Bar

        """
        if self._open is None:  # No tick was received
            self._open = self._last_close
            self._high = self._last_close
            self._low = self._last_close
            self._close = self._last_close

        cdef Bar bar = Bar(
            bar_type=self._bar_type,
            open=self._open,
            high=self._high,
            low=self._low,
            close=self._close,
            volume=Quantity(self.volume, self.size_precision),
            ts_event=ts_event,  # TODO: Hardcoded identical for now...
            ts_init=ts_event,
        )

        self._last_close = self._close
        self.reset()
        return bar


cdef class BarAggregator:
    """
    Provides a means of aggregating specified bars and sending to a registered handler.

    Parameters
    ----------
    instrument : Instrument
        The instrument for the aggregator.
    bar_type : BarType
        The bar type for the aggregator.
    handler : Callable[[Bar], None]
        The bar handler for the aggregator.
    logger : Logger
        The logger for the aggregator.

    Raises
    ------
    ValueError
        If `instrument.id` != `bar_type.instrument_id`.
    """

    def __init__(
        self,
        Instrument instrument not None,
        BarType bar_type not None,
        handler not None: Callable[[Bar], None],
        Logger logger not None,
    ):
        Condition.equal(instrument.id, bar_type.instrument_id, "instrument.id", "bar_type.instrument_id")

        self.bar_type = bar_type
        self._handler = handler
        self._log = LoggerAdapter(
            component_name=type(self).__name__,
            logger=logger,
        )
        self._builder = BarBuilder(
            instrument=instrument,
            bar_type=self.bar_type,
        )

    cpdef void handle_quote_tick(self, QuoteTick tick) except *:
        """
        Update the aggregator with the given tick.

        Parameters
        ----------
        tick : QuoteTick
            The tick for the update.

        """
        Condition.not_none(tick, "tick")

        self._apply_update(
            price=tick.extract_price(self.bar_type.spec.price_type),
            size=tick.extract_volume(self.bar_type.spec.price_type),
            ts_event=tick.ts_event,
        )

    cpdef void handle_trade_tick(self, TradeTick tick) except *:
        """
        Update the aggregator with the given tick.

        Parameters
        ----------
        tick : TradeTick
            The tick for the update.

        """
        Condition.not_none(tick, "tick")

        self._apply_update(
            price=tick.price,
            size=tick.size,
            ts_event=tick.ts_event,
        )

    cdef void _apply_update(self, Price price, Quantity size, int64_t ts_event) except *:
        raise NotImplementedError("method must be implemented in the subclass")  # pragma: no cover

    cdef void _build_now_and_send(self) except *:
        cdef Bar bar = self._builder.build_now()
        self._handler(bar)

    cdef void _build_and_send(self, int64_t ts_event) except *:
        cdef Bar bar = self._builder.build(ts_event)
        self._handler(bar)


cdef class TickBarAggregator(BarAggregator):
    """
    Provides a means of building tick bars from ticks.

    When received tick count reaches the step threshold of the bar
    specification, then a bar is created and sent to the handler.

    Parameters
    ----------
    instrument : Instrument
        The instrument for the aggregator.
    bar_type : BarType
        The bar type for the aggregator.
    handler : Callable[[Bar], None]
        The bar handler for the aggregator.
    logger : Logger
        The logger for the aggregator.

    Raises
    ------
    ValueError
        If `instrument.id` != `bar_type.instrument_id`.
    """

    def __init__(
        self,
        Instrument instrument not None,
        BarType bar_type not None,
        handler not None: Callable[[Bar], None],
        Logger logger not None,
    ):
        super().__init__(
            instrument=instrument,
            bar_type=bar_type,
            handler=handler,
            logger=logger,
        )

    cdef void _apply_update(self, Price price, Quantity size, int64_t ts_event) except *:
        self._builder.update(price, size, ts_event)

        if self._builder.count == self.bar_type.spec.step:
            self._build_now_and_send()


cdef class VolumeBarAggregator(BarAggregator):
    """
    Provides a means of building volume bars from ticks.

    When received volume reaches the step threshold of the bar
    specification, then a bar is created and sent to the handler.

    Parameters
    ----------
    instrument : Instrument
        The instrument for the aggregator.
    bar_type : BarType
        The bar type for the aggregator.
    handler : Callable[[Bar], None]
        The bar handler for the aggregator.
    logger : Logger
        The logger for the aggregator.

    Raises
    ------
    ValueError
        If `instrument.id` != `bar_type.instrument_id`.
    """

    def __init__(
        self,
        Instrument instrument not None,
        BarType bar_type not None,
        handler not None: Callable[[Bar], None],
        Logger logger not None,
    ):
        super().__init__(
            instrument=instrument,
            bar_type=bar_type,
            handler=handler,
            logger=logger,
        )

    cdef void _apply_update(self, Price price, Quantity size, int64_t ts_event) except *:
        size_update = size

        while size_update > 0:  # While there is size to apply
            if self._builder.volume + size_update < self.bar_type.spec.step:
                # Update and break
                self._builder.update(
                    price=price,
                    size=Quantity(size_update, precision=size.precision),
                    ts_event=ts_event,
                )
                break

            size_diff: Decimal = self.bar_type.spec.step - self._builder.volume
            # Update builder to the step threshold
            self._builder.update(
                price=price,
                size=Quantity(size_diff, precision=size.precision),
                ts_event=ts_event,
            )

            # Build a bar and reset builder
            self._build_now_and_send()

            # Decrement the update size
            size_update -= size_diff
            assert size_update >= 0


cdef class ValueBarAggregator(BarAggregator):
    """
    Provides a means of building value bars from ticks.

    When received value reaches the step threshold of the bar
    specification, then a bar is created and sent to the handler.

    Parameters
    ----------
    instrument : Instrument
        The instrument for the aggregator.
    bar_type : BarType
        The bar type for the aggregator.
    handler : Callable[[Bar], None]
        The bar handler for the aggregator.
    logger : Logger
        The logger for the aggregator.

    Raises
    ------
    ValueError
        If `instrument.id` != `bar_type.instrument_id`.
    """

    def __init__(
        self,
        Instrument instrument not None,
        BarType bar_type not None,
        handler not None: Callable[[Bar], None],
        Logger logger not None,
    ):
        super().__init__(
            instrument=instrument,
            bar_type=bar_type,
            handler=handler,
            logger=logger,
        )

        self._cum_value = Decimal(0)  # Cumulative value

    cpdef object get_cumulative_value(self):
        """
        Return the current cumulative value of the aggregator.

        Returns
        -------
        Decimal

        """
        return self._cum_value

    cdef void _apply_update(self, Price price, Quantity size, int64_t ts_event) except *:
        size_update = size

        while size_update > 0:  # While there is value to apply
            value_update = price * size_update  # Calculated value in quote currency
            if self._cum_value + value_update < self.bar_type.spec.step:
                # Update and break
                self._cum_value = self._cum_value + value_update
                self._builder.update(
                    price=price,
                    size=Quantity(size_update, precision=size.precision),
                    ts_event=ts_event,
                )
                break

            value_diff: Decimal = self.bar_type.spec.step - self._cum_value
            size_diff: Decimal = size_update * (value_diff / value_update)
            # Update builder to the step threshold
            self._builder.update(
                price=price,
                size=Quantity(size_diff, precision=size.precision),
                ts_event=ts_event,
            )

            # Build a bar and reset builder and cumulative value
            self._build_now_and_send()
            self._cum_value = Decimal(0)

            # Decrement the update size
            size_update -= size_diff
            assert size_update >= 0


cdef class TimeBarAggregator(BarAggregator):
    """
    Provides a means of building time bars from ticks with an internal timer.

    When the time reaches the next time interval of the bar specification, then
    a bar is created and sent to the handler.

    Parameters
    ----------
    instrument : Instrument
        The instrument for the aggregator.
    bar_type : BarType
        The bar type for the aggregator.
    handler : Callable[[Bar], None]
        The bar handler for the aggregator.
    clock : Clock
        The clock for the aggregator.
    logger : Logger
        The logger for the aggregator.

    Raises
    ------
    ValueError
        If `instrument.id` != `bar_type.instrument_id`.
    """
    def __init__(
        self,
        Instrument instrument not None,
        BarType bar_type not None,
        handler not None: Callable[[Bar], None],
        Clock clock not None,
        Logger logger not None,
    ):
        super().__init__(
            instrument=instrument,
            bar_type=bar_type,
            handler=handler,
            logger=logger,
        )

        self._clock = clock
        self.interval = self._get_interval()
        self.interval_ns = self._get_interval_ns()
        self._set_build_timer()
        self.next_close_ns = self._clock.timer(str(self.bar_type)).next_time_ns
        self._build_on_next_tick = False
        self._stored_close_ns = 0

    cpdef datetime get_start_time(self):
        """
        Return the start time for the aggregators next bar.

        Returns
        -------
        datetime
            The timestamp (UTC).

        """
        cdef datetime now = self._clock.utc_now()
        cdef int step = self.bar_type.spec.step

        cdef datetime start_time
        if self.bar_type.spec.aggregation == BarAggregation.SECOND:
            start_time = now - timedelta(
                seconds=now.second % step,
                microseconds=now.microsecond,
            )
        elif self.bar_type.spec.aggregation == BarAggregation.MINUTE:
            start_time = now - timedelta(
                minutes=now.minute % step,
                seconds=now.second,
                microseconds=now.microsecond,
            )
        elif self.bar_type.spec.aggregation == BarAggregation.HOUR:
            start_time = now - timedelta(
                hours=now.hour % step,
                minutes=now.minute,
                seconds=now.second,
                microseconds=now.microsecond,
            )
        elif self.bar_type.spec.aggregation == BarAggregation.DAY:
            start_time = now - timedelta(
                days=now.day % step,
                hours=now.hour,
                minutes=now.minute,
                seconds=now.second,
                microseconds=now.microsecond,
            )
        else:  # pragma: no cover (design-time error)
            raise ValueError(
                f"Aggregation not a time, "
                f"was {BarAggregationParser.to_str(self.bar_type.spec.aggregation)}",
            )

        return start_time

    cpdef void set_partial(self, Bar partial_bar) except *:
        """
        Set the initial values for a partially completed bar.

        This method can only be called once per instance.

        Parameters
        ----------
        partial_bar : Bar
            The partial bar with values to set.

        """
        self._builder.set_partial(partial_bar)

    cpdef void stop(self) except *:
        """
        Stop the bar aggregator.
        """
        self._clock.cancel_timer(str(self.bar_type))

    cdef timedelta _get_interval(self):
        cdef BarAggregation aggregation = self.bar_type.spec.aggregation
        cdef int step = self.bar_type.spec.step

        if aggregation == BarAggregation.SECOND:
            return timedelta(seconds=(1 * step))
        elif aggregation == BarAggregation.MINUTE:
            return timedelta(minutes=(1 * step))
        elif aggregation == BarAggregation.HOUR:
            return timedelta(hours=(1 * step))
        elif aggregation == BarAggregation.DAY:
            return timedelta(days=(1 * step))
        else:
            # Design time error
            raise ValueError(f"Aggregation not time range, "
                             f"was {BarAggregationParser.to_str(aggregation)}")

    cdef int64_t _get_interval_ns(self):
        cdef BarAggregation aggregation = self.bar_type.spec.aggregation
        cdef int step = self.bar_type.spec.step

        if aggregation == BarAggregation.SECOND:
            return secs_to_nanos(step)
        elif aggregation == BarAggregation.MINUTE:
            return secs_to_nanos(step) * 60
        elif aggregation == BarAggregation.HOUR:
            return secs_to_nanos(step) * 60 * 60
        elif aggregation == BarAggregation.DAY:
            return secs_to_nanos(step) * 60 * 60 * 24
        else:
            # Design time error
            raise ValueError(f"Aggregation not time range, "
                             f"was {BarAggregationParser.to_str(aggregation)}")

    cpdef void _set_build_timer(self) except *:
        cdef str timer_name = str(self.bar_type)

        self._clock.set_timer(
            name=timer_name,
            interval=self.interval,
            start_time=self.get_start_time(),
            stop_time=None,
            callback=self._build_event,
        )

        self._log.debug(f"Started timer {timer_name}.")

    cdef void _apply_update(self, Price price, Quantity size, int64_t ts_event) except *:
        if self._clock.is_test_clock:
            if self.next_close_ns < ts_event:
                # Build bar first, then update
                self._build_bar(self.next_close_ns)
                self._builder.update(price, size, ts_event)
                return
            elif self.next_close_ns == ts_event:
                # Update first, then build bar
                self._builder.update(price, size, ts_event)
                self._build_bar(self.next_close_ns)
                return

        self._builder.update(price, size, ts_event)
        if self._build_on_next_tick:  # (fast C-level check)
            self._build_and_send(self._stored_close_ns)
            # Reset flag and clear stored close
            self._build_on_next_tick = False
            self._stored_close_ns = 0

    cpdef void _build_bar(self, int64_t ts_event) except *:
        cdef TestTimer timer = self._clock.timer(str(self.bar_type))
        cdef TimeEvent event = timer.pop_next_event()
        self._build_event(event)
        self.next_close_ns = timer.next_time_ns

    cpdef void _build_event(self, TimeEvent event) except *:
        if not self._builder.initialized:
            # Set flag to build on next close with the stored close time
            self._build_on_next_tick = True
            self._stored_close_ns = self.next_close_ns
            return

        self._build_and_send(ts_event=event.ts_event)


cdef class BulkTickBarBuilder:
    """
    Provides a temporary builder for tick bars from a bulk tick order.

    Parameters
    ----------
    instrument : Instrument
        The instrument for the aggregator.
    bar_type : BarType
        The bar_type to build.
    logger : Logger
        The logger for the bar aggregator.
    callback : Callable[[Bar], None]
        The delegate to call with the built bars.

    Raises
    ------
    ValueError
        If `callback` is not of type `Callable`.
    ValueError
        If `instrument.id` != `bar_type.instrument_id`.
    """

    def __init__(
        self,
        Instrument instrument not None,
        BarType bar_type not None,
        Logger logger not None,
        callback not None: Callable[[Bar], None],
    ):
        Condition.callable(callback, "callback")

        self.bars = []
        self.aggregator = TickBarAggregator(
            instrument=instrument,
            bar_type=bar_type,
            handler=self.bars.append,
            logger=logger,
        )
        self.callback = callback

    def receive(self, list ticks):
        """
        Receive the bulk list of ticks and build aggregated bars.

        Then send the bar type and bars list on to the registered callback.

        Parameters
        ----------
        ticks : list[Tick]
            The ticks for aggregation.

        """
        Condition.not_none(ticks, "ticks")

        if self.aggregator.bar_type.spec.price_type == PriceType.LAST:
            for i in range(len(ticks)):
                self.aggregator.handle_trade_tick(ticks[i])
        else:
            for i in range(len(ticks)):
                self.aggregator.handle_quote_tick(ticks[i])

        self.callback(self.bars)


cdef class BulkTimeBarUpdater:
    """
    Provides a temporary updater for time bars from a bulk tick order.

    Parameters
    ----------
    aggregator : TimeBarAggregator
        The time bar aggregator to update.
    """

    def __init__(self, TimeBarAggregator aggregator not None):
        self.aggregator = aggregator
        self.start_time_ns = self.aggregator.next_close_ns - self.aggregator.interval_ns

    def receive(self, list ticks):
        """
        Receive the bulk list of ticks and update the aggregator.

        Parameters
        ----------
        ticks : list[Tick]
            The ticks for updating.

        """
        if self.aggregator.bar_type.spec.price_type == PriceType.LAST:
            for i in range(len(ticks)):
                if ticks[i].ts_event < self.start_time_ns:
                    continue  # Price not applicable to this bar
                self.aggregator.handle_trade_tick(ticks[i])
        else:
            for i in range(len(ticks)):
                if ticks[i].ts_event < self.start_time_ns:
                    continue  # Price not applicable to this bar
                self.aggregator.handle_quote_tick(ticks[i])
