import {
  stagingRuntime,
  boundedBody,
  sandboxProviders
} from '../_shared/staging-runtime.ts';

import {
  createSandboxProvider,
  constantEqual
} from '../_shared/payment-providers.mjs';

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const respond = (status: number, value: object) =>
  new Response(JSON.stringify(value), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store'
    }
  });

function validTimestamp(value: unknown): value is string {
  if (typeof value !== 'string') return false;

  if (
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(value)
  ) {
    return false;
  }

  return Number.isFinite(Date.parse(value));
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return respond(405, { error: 'Method denied' });
  }

  try {
    const runtime = stagingRuntime('PAYMENT_MAINTENANCE_ENABLED');
    const secret = Deno.env.get('STAGING_JOB_TOKEN') || '';
    const supplied = request.headers.get('x-job-token') || '';

    if (
      secret.length < 32 ||
      !constantEqual(supplied, secret)
    ) {
      return respond(403, { error: 'Job authorization required' });
    }

    const body = JSON.parse(await boundedBody(request));

    if (
      !body ||
      typeof body !== 'object' ||
      Array.isArray(body) ||
      typeof body.action !== 'string'
    ) {
      return respond(400, { error: 'Invalid maintenance request' });
    }

    if (body.action === 'reconcile') {
      if (!UUID.test(body.intent_id || '')) {
        return respond(400, { error: 'Invalid payment intent' });
      }

      const work = await runtime.server.rpc(
        'payment_reconciliation_work',
        { p_intent: body.intent_id }
      );

      if (work.error || !work.data) {
        return respond(409, { error: 'Settled attempt required' });
      }

      const value = work.data;
      const config = sandboxProviders()[value.channel];

      if (
        !config ||
        config.mode !== 'sandbox' ||
        config.providerId !== value.provider ||
        config.merchantId !== value.merchant_id ||
        typeof value.reference !== 'string' ||
        !value.reference
      ) {
        return respond(409, { error: 'Provider binding unavailable' });
      }

      const report = await createSandboxProvider(
        value.channel,
        config
      ).reconcile(value.reference);

      const result = await runtime.server.rpc(
        'payment_reconcile',
        {
          p_intent: body.intent_id,
          p_provider: value.provider,
          p_report: report.report_reference,
          p_amount: report.net_minor,
          p_currency: report.currency
        }
      );

      if (result.error) {
        throw new Error('Reconciliation was not recorded');
      }

      return respond(200, {
        recorded: true,
        matched: result.data
      });
    }

    if (body.action === 'billing_cycle') {
      if (
        !UUID.test(body.request_id || '') ||
        !validTimestamp(body.starts_at) ||
        !validTimestamp(body.ends_at) ||
        Date.parse(body.ends_at) <= Date.parse(body.starts_at)
      ) {
        return respond(400, { error: 'Invalid billing period' });
      }

      const result = await runtime.server.rpc(
        'billing_prepare_cycle',
        {
          p_request: body.request_id,
          p_start: body.starts_at,
          p_end: body.ends_at
        }
      );

      if (result.error || !result.data) {
        return respond(409, { error: 'Billing cycle unavailable' });
      }

      return respond(200, {
        cycle_id: result.data,
        charged: false
      });
    }

    if (body.action === 'billing_settlement') {
      if (
        !UUID.test(body.cycle_id || '') ||
        !UUID.test(body.intent_id || '')
      ) {
        return respond(400, { error: 'Invalid settlement references' });
      }

      const result = await runtime.server.rpc(
        'billing_apply_settlement',
        {
          p_cycle: body.cycle_id,
          p_intent: body.intent_id
        }
      );

      if (result.error) {
        return respond(409, {
          error: 'Verified settlement could not be applied'
        });
      }

      return respond(200, { recorded: true });
    }

    if (body.action === 'expire_tickets') {
      const result = await runtime.server.rpc(
        'expire_ticket_holds',
        { p_limit: 50 }
      );

      if (result.error) {
        return respond(409, { error: 'Ticket expiry unavailable' });
      }

      return respond(200, { expired: result.data });
    }

    return respond(400, { error: 'Unsupported maintenance action' });

  } catch {
    return respond(503, {
      error: 'Staging maintenance unavailable'
    });
  }
});