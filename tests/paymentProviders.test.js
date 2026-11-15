import test from 'node:test';
import assert from 'node:assert/strict';

import {
  constantEqual,
  createSandboxProvider,
  minorAmount,
  normalizePaymentEvent,
  verifySandboxSignature
} from '../supabase/functions/_shared/payment-providers.mjs';

const attempt = {
  attempt_id: '4c96a86e-5d82-4ac3-8a35-eae6f06a750a',
  amount_minor: 12500,
  currency: 'ZMW'
};

const config = {
  mode: 'sandbox',
  secret: 'server-secret',
  merchantId: 'merchant-zm',
  baseUrl: 'https://sandbox.example.test/api',
  allowedOrigins: ['https://sandbox.example.test']
};

function mockResponse(value, options = {}) {
  return {
    ok: options.ok ?? true,
    json: async () => {
      if (options.invalidJson) {
        throw new Error('Invalid JSON');
      }

      return value;
    }
  };
}

test('minor-unit amounts and constant comparison reject unsafe input', () => {
  assert.equal(minorAmount(1), 1);
  assert.equal(minorAmount(12500), 12500);

  assert.throws(() => minorAmount(0));
  assert.throws(() => minorAmount(-1));
  assert.throws(() => minorAmount(1.5));
  assert.throws(() => minorAmount(Number.MAX_SAFE_INTEGER));
  assert.throws(() => minorAmount(100000000001));

  assert.equal(constantEqual('same', 'same'), true);
  assert.equal(constantEqual('same', 'different'), false);
  assert.equal(constantEqual('', ''), true);
});

test('verified webhook signature is bound to body and a five-minute window', async () => {
  const raw = JSON.stringify({ event: 'settled' });
  const timestamp = String(1_800_000_000);

  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode('webhook-secret'),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const bytes = new Uint8Array(
    await crypto.subtle.sign(
      'HMAC',
      key,
      new TextEncoder().encode(timestamp + '.' + raw)
    )
  );

  const signature = [...bytes]
    .map(value => value.toString(16).padStart(2, '0'))
    .join('');

  assert.equal(
    await verifySandboxSignature(
      raw,
      timestamp,
      signature,
      'webhook-secret',
      1_800_000_000_000
    ),
    true
  );

  assert.equal(
    await verifySandboxSignature(
      raw + 'x',
      timestamp,
      signature,
      'webhook-secret',
      1_800_000_000_000
    ),
    false
  );

  assert.equal(
    await verifySandboxSignature(
      raw,
      timestamp,
      signature,
      'webhook-secret',
      1_800_000_301_000
    ),
    false
  );

  assert.equal(
    await verifySandboxSignature(
      raw,
      timestamp,
      signature,
      '',
      1_800_000_000_000
    ),
    false
  );
});

test('provider events require exact merchant, ZMW and a real UUID', () => {
  const body = {
    merchant_id: 'merchant-zm',
    type: 'settled',
    currency: 'ZMW',
    attempt_id: attempt.attempt_id,
    event_id: 'evt-1',
    reference: 'provider-1',
    amount_minor: 12500
  };

  assert.deepEqual(
    normalizePaymentEvent(body, 'merchant-zm'),
    {
      attempt_id: attempt.attempt_id,
      event_id: 'evt-1',
      reference: 'provider-1',
      type: 'settled',
      amount_minor: 12500,
      currency: 'ZMW',
      merchant_id: 'merchant-zm'
    }
  );

  assert.throws(() =>
    normalizePaymentEvent(
      { ...body, attempt_id: '------------------------------------' },
      'merchant-zm'
    )
  );

  assert.throws(() =>
    normalizePaymentEvent(
      { ...body, merchant_id: 'other' },
      'merchant-zm'
    )
  );

  assert.throws(() =>
    normalizePaymentEvent(
      { ...body, currency: 'USD' },
      'merchant-zm'
    )
  );

  assert.throws(() =>
    normalizePaymentEvent(
      { ...body, type: 'unknown' },
      'merchant-zm'
    )
  );

  assert.throws(() =>
    normalizePaymentEvent(
      { ...body, event_id: 'x'.repeat(201) },
      'merchant-zm'
    )
  );
});

test('mobile-money sandbox adapter sends only server-priced bounded fields', async () => {
  let seen;

  const provider = createSandboxProvider(
    'mobile_money',
    config,
    async (url, options) => {
      seen = {
        url: String(url),
        options,
        body: JSON.parse(options.body)
      };

      return mockResponse({
        reference: 'provider-42',
        checkout_url: 'https://sandbox.example.test/continue'
      });
    }
  );

  const result = await provider.checkout(attempt, {
    phone: '+260971234567'
  });

  assert.equal(result.reference, 'provider-42');

  assert.equal(
    result.checkout_url,
    'https://sandbox.example.test/continue'
  );

  assert.equal(
    seen.url,
    'https://sandbox.example.test/sandbox/checkout'
  );

  assert.deepEqual(seen.body, {
    merchant_id: 'merchant-zm',
    merchant_reference: attempt.attempt_id,
    amount_minor: 12500,
    currency: 'ZMW',
    channel: 'mobile_money',
    phone: '+260971234567'
  });

  assert.match(seen.options.headers.Authorization, /^Bearer /);

  await assert.rejects(
    () => provider.checkout(attempt, {
      phone: '+260971234567',
      cvv: '123'
    }),
    /not accepted/
  );

  await assert.rejects(
    () => provider.checkout(
      { ...attempt, amount_minor: 0 },
      { phone: '+260971234567' }
    )
  );

  await assert.rejects(
    () => provider.checkout(
      { ...attempt, currency: 'USD' },
      { phone: '+260971234567' }
    )
  );
});

test('adapter blocks unapproved origins and redirect destinations', async () => {
  assert.throws(() =>
    createSandboxProvider('card', {
      ...config,
      baseUrl: 'http://sandbox.example.test'
    })
  );

  const provider = createSandboxProvider(
    'card',
    config,
    async () => mockResponse({
      reference: 'provider-42',
      checkout_url: 'https://evil.example/collect'
    })
  );

  await assert.rejects(
    () => provider.checkout(attempt, {}),
    /Unapproved checkout destination/
  );
});

test('checkout rejects missing or malformed provider references', async () => {
  const missingReference = createSandboxProvider(
    'card',
    config,
    async () => mockResponse({
      checkout_url: 'https://sandbox.example.test/continue'
    })
  );

  await assert.rejects(
    () => missingReference.checkout(attempt, {}),
    /Provider reference unavailable/
  );

  const shortReference = createSandboxProvider(
    'card',
    config,
    async () => mockResponse({
      reference: 'x',
      checkout_url: null
    })
  );

  await assert.rejects(
    () => shortReference.checkout(attempt, {}),
    /Provider reference unavailable/
  );
});

test('provider HTTP failures and invalid JSON are not treated as success', async () => {
  const failedProvider = createSandboxProvider(
    'card',
    config,
    async () => mockResponse({}, { ok: false })
  );

  await assert.rejects(
    () => failedProvider.checkout(attempt, {}),
    /Provider result uncertain/
  );

  const invalidJsonProvider = createSandboxProvider(
    'card',
    config,
    async () => mockResponse(null, { invalidJson: true })
  );

  await assert.rejects(
    () => invalidJsonProvider.checkout(attempt, {})
  );
});

test('refund response must echo the exact merchant reference', async () => {
  const validProvider = createSandboxProvider(
    'card',
    config,
    async (url, options) => {
      const body = JSON.parse(options.body);

      return mockResponse({
        merchant_reference: body.merchant_reference
      });
    }
  );

  const result = await validProvider.refund(
    'provider-payment-42',
    12500,
    'refund:request-42'
  );

  assert.deepEqual(result, {
    reference: 'refund:request-42',
    pending: true
  });

  const mismatchedProvider = createSandboxProvider(
    'card',
    config,
    async () => mockResponse({
      merchant_reference: 'another-refund'
    })
  );

  await assert.rejects(
    () => mismatchedProvider.refund(
      'provider-payment-42',
      12500,
      'refund:request-42'
    ),
    /Refund reference mismatch/
  );

  await assert.rejects(
    () => validProvider.refund('', 12500, 'refund:request-42')
  );

  await assert.rejects(
    () => validProvider.refund(
      'provider-payment-42',
      0,
      'refund:request-42'
    )
  );
});

test('reconciliation rejects mismatched merchant, currency and invalid totals', async () => {
  const validProvider = createSandboxProvider(
    'card',
    config,
    async () => mockResponse({
      merchant_id: 'merchant-zm',
      currency: 'ZMW',
      net_minor: 12500,
      report_reference: 'report-42'
    })
  );

  assert.deepEqual(
    await validProvider.reconcile('provider-payment-42'),
    {
      report_reference: 'report-42',
      net_minor: 12500,
      currency: 'ZMW'
    }
  );

  const wrongMerchant = createSandboxProvider(
    'card',
    config,
    async () => mockResponse({
      merchant_id: 'another-merchant',
      currency: 'ZMW',
      net_minor: 12500,
      report_reference: 'report-42'
    })
  );

  await assert.rejects(
    () => wrongMerchant.reconcile('provider-payment-42'),
    /Invalid reconciliation report/
  );

  const wrongCurrency = createSandboxProvider(
    'card',
    config,
    async () => mockResponse({
      merchant_id: 'merchant-zm',
      currency: 'USD',
      net_minor: 12500,
      report_reference: 'report-42'
    })
  );

  await assert.rejects(
    () => wrongCurrency.reconcile('provider-payment-42'),
    /Invalid reconciliation report/
  );

  const invalidAmount = createSandboxProvider(
    'card',
    config,
    async () => mockResponse({
      merchant_id: 'merchant-zm',
      currency: 'ZMW',
      net_minor: -1,
      report_reference: 'report-42'
    })
  );

  await assert.rejects(
    () => invalidAmount.reconcile('provider-payment-42'),
    /Invalid reconciliation report/
  );
});