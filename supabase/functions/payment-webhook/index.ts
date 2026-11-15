import {
  stagingRuntime,
  boundedBody,
  sandboxProviders
} from '../_shared/staging-runtime.ts';

import {
  verifySandboxSignature,
  normalizePaymentEvent
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

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return respond(405, { error: 'Method denied' });
  }

  try {
    const runtime = stagingRuntime('PAYMENT_WEBHOOK_ENABLED');
    const channel = new URL(request.url).searchParams.get('channel');

    if (!['mobile_money', 'card'].includes(channel || '')) {
      return respond(400, { error: 'Provider unavailable' });
    }

    const config = sandboxProviders()[channel!];

    if (
      config?.mode !== 'sandbox' ||
      !config.webhookSecret ||
      !config.providerId ||
      !config.merchantId
    ) {
      return respond(503, { error: 'Sandbox webhook unavailable' });
    }

    const raw = await boundedBody(request, 65536);

    const validSignature = await verifySandboxSignature(
      raw,
      request.headers.get('x-zammarket-timestamp'),
      request.headers.get('x-zammarket-signature'),
      config.webhookSecret
    );

    if (!validSignature) {
      return respond(401, { error: 'Invalid signature or timestamp' });
    }

    const body = JSON.parse(raw);

    if (
      !body ||
      typeof body !== 'object' ||
      Array.isArray(body)
    ) {
      return respond(400, { error: 'Invalid event body' });
    }

    let result;

    if (
      body.type === 'refund_succeeded' ||
      body.type === 'refund_failed'
    ) {
      if (
        !UUID.test(body.refund_id || '') ||
        typeof body.event_id !== 'string' ||
        body.event_id.length < 1 ||
        body.event_id.length > 200 ||
        typeof body.reference !== 'string' ||
        body.reference.length < 3 ||
        body.reference.length > 200 ||
        body.merchant_id !== config.merchantId ||
        body.currency !== 'ZMW' ||
        !Number.isSafeInteger(body.amount_minor) ||
        body.amount_minor <= 0
      ) {
        return respond(400, { error: 'Refund event binding invalid' });
      }

      result = await runtime.server.rpc(
        'payment_apply_refund_event',
        {
          p_refund: body.refund_id,
          p_provider: config.providerId,
          p_merchant: config.merchantId,
          p_event: body.event_id,
          p_reference: body.reference,
          p_amount: body.amount_minor,
          p_currency: 'ZMW',
          p_succeeded: body.type === 'refund_succeeded'
        }
      );
    } else {
      const event = normalizePaymentEvent(
        body,
        config.merchantId
      );

      result = await runtime.server.rpc(
        'payment_apply_verified_event',
        {
          p_attempt: event.attempt_id,
          p_provider: config.providerId,
          p_merchant: config.merchantId,
          p_reference: event.reference,
          p_event: event.event_id,
          p_type: event.type,
          p_amount: event.amount_minor,
          p_currency: 'ZMW'
        }
      );
    }

    if (result.error) {
      return respond(503, {
        error: 'Event not committed; retry or reconcile'
      });
    }

    return respond(200, { accepted: true });

  } catch {
    return respond(503, {
      error: 'Sandbox webhook unavailable'
    });
  }
});