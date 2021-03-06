""" Job to perform MN service discovery """

import asyncio, time

class MetricDaemon(object):
	"""Service to manage extended masternode sync"""
	headers = {"Server": "Veles Core Masternode (MetricDaemon)"}
	intervals = {
		'hourly': 3600,
		'daily': 3600*24
	}

	def __init__(self, config, logger, metric_repository, dapp_registry):
		"""Constructor"""
		self.repo = metric_repository
		self.logger = logger
		self.config = config
		self.dapps = dapp_registry.get_all()

	def start_job(self):
		""" Starts service discovery job """
		loop = asyncio.get_event_loop()
		loop.run_until_complete(asyncio.gather(
			self.recent_metrics_update_task('hourly'),
			self.recent_metrics_update_task('daily'),
			self.global_metrics_update_task('daily'),
			))
		loop.run_forever()

	@asyncio.coroutine
	def recent_metrics_update_task(self, interval_name):
		prefix = 'MetricDaemon::recent_metrics_update_task [%s]: ' % interval_name
		interval = self.intervals[interval_name]
		self.logger.info(prefix + 'Starting new asynchronous task')
		next_sleep_seconds = 10 	# first sleep is not important

		while True:
			self.logger.debug(prefix + '[ sleeping for %i s / running %s ]' % (next_sleep_seconds, interval_name))
			yield from asyncio.sleep(next_sleep_seconds)

			action_started_at = time.time()
			#try:
			self.update_recent_metrics(interval_name)

			#except Exception as e:
			#	self.logger.error(prefix + 'Error: [task will restart]: ' + str(e))
			#	continue

			action_duration = time.time() - action_started_at

			if action_duration > interval:
				next_sleep_seconds = 0
				self.logger.warning(prefix + "Action took longer than it's schedule! [ took %is / scheduled %s ]" % (
					action_duration,
					interval_name
					))
			else:
				next_sleep_seconds = interval - action_duration

	@asyncio.coroutine
	def global_metrics_update_task(self, interval_name):
		prefix = 'MetricDaemon::global_metrics_update_task [%s]: ' % interval_name
		interval = self.intervals[interval_name]
		self.logger.info(prefix + 'Starting new asynchronous task')
		next_sleep_seconds = 10 	# first sleep is not important

		while True:
			self.logger.debug(prefix + '[ sleeping for %i s / running %s ]' % (next_sleep_seconds, interval_name))
			yield from asyncio.sleep(next_sleep_seconds)

			action_started_at = time.time()
			self.update_global_metrics(interval_name)
			action_duration = time.time() - action_started_at

			if action_duration > interval:
				next_sleep_seconds = 0
				self.logger.warning(prefix + "Action took longer than it's schedule! [ took %is / scheduled %s ]" % (
					action_duration,
					interval_name
					))
			else:
				next_sleep_seconds = interval - action_duration

	def update_recent_metrics(self, interval_name):
		for dapp_name, dapp_facade in self.dapps.items():
			self.logger.debug('MetricDaemon::update_recent_metrics: Updating %s metrics of dApp %s' % (interval_name, dapp_name))
			dapp_facade.get_metric_service().update_recent_metrics(interval_name)

	def update_global_metrics(self, interval_name):
		for dapp_name, dapp_facade in self.dapps.items():
			self.logger.debug('MetricDaemon::update_global_metrics: Updating %s metrics of dApp %s' % (interval_name, dapp_name))
			# todo: only if metric_service it's a child of AbstractGlobalMetricService
			dapp_facade.get_metric_service().update_global_metrics(interval_name)