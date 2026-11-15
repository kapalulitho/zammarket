# Payment integration boundary — architecture only, no activation

No payment SDK, merchant credentials, live charge, checkout endpoint or payout exists in this batch. Do not derive a successful payment from a client callback, local state, cart subtotal, marked-sold listing or planner checklist.

Future approved flow:

1. Authenticated customer asks an approved server endpoint for an order quote. The server derives account identity and fetches seller, variants, live price, availability and stock under verified access. It validates quantities, ZMW minor-unit arithmetic, fees, delivery and allowed item types. The browser's subtotal is advisory only.
2. A transaction creates an immutable order/price snapshot and uses a unique idempotency key. Authorised order participants receive only necessary fields. Do not add real order creation until approval.
3. A server-held provider adapter creates a payment intent. Secrets and webhook signing keys stay server-side. Use a separately approved provider sandbox and test merchant account; never production credentials for staging.
4. Signed provider webhooks are verified over the original payload, checked for replay, idempotency, merchant, order, amount and currency. A trusted server transition records payment success; browser redirects never prove success.
5. Atomic order/stock transitions prevent overselling. Approval is required before reservation, settlement or dispatch. Refunds, cancellations, disputes and failed payments need audited, idempotent transitions and clear recovery.
6. Revenue uses actual settled transactions minus verified refunds/provider fees, not local commission scenarios. Seller analytics must label its measurement source and period. Sponsored placement requires an approved campaign and explicit sponsored label.

Before launch: confirm Zambia provider support, merchant compliance, tax and consumer policies, chargebacks, refunds, fee disclosure, retention and access controls with the appropriate specialists. No provider recommendation or commercial terms are asserted here. All existing held migrations remain on HOLD.
