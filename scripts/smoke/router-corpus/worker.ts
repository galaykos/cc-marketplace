export async function drain(queue) {
  const jobs = await Promise.all(queue.take(10))
  for (const job of jobs) {
    await job.run()
    logger.info('job done', { correlation_id: job.id })
  }
}
