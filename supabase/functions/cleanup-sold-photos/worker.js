export async function runCleanup(client, deadline = Date.now() + 120000) {
  let completed = 0;
  for (let index = 0; index < 10; index++) {
    if (Date.now() >= deadline) break;
    const {data: job, error} = await client.rpc('claim_photo_cleanup');
    if (error) throw error;
    if (!job) break;
    if (!Array.isArray(job.paths) || !job.paths.length || job.paths.length > 5 || job.paths.some(path =>
      typeof path !== 'string' || !path.startsWith(`${job.owner_id}/`) || path.includes('..') || path.includes('\\'))) {
      throw new Error('Unsafe cleanup paths; manual review required');
    }
    const {error: removeError} = await client.storage.from('listing-images').remove(job.paths);
    if (removeError) throw removeError;
    const {error: finishError} = await client.rpc('finish_photo_cleanup', {p_id: job.listing_id, p_token: job.token});
    if (finishError) throw finishError;
    completed++;
  }
  return completed;
}
