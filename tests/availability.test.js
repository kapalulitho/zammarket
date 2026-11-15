import test from 'node:test';
import assert from 'node:assert/strict';
import { availability, lusakaDate, availabilityLabel } from '../src/lib/availability.js';

test('changes at midnight in Zambia, not midnight UTC', () => {
  const listing = { status: 'active', available_from: '2026-10-30' };
  assert.equal(availability(listing, new Date('2026-10-29T21:59:59.999Z')), 'Coming Soon');
  assert.equal(availability(listing, new Date('2026-10-29T22:00:00Z')), 'Available');
});
test('available remains available days, months, and years later without writes', () => {
  for (const date of ['2026-10-30', '2026-10-31', '2026-11-30', '2027-12-31']) {
    assert.equal(availability({ available_from: '2026-10-30' }, new Date(`${date}T12:00:00Z`)), 'Available');
  }
});
test('seller overrides always take priority over the date', () => {
  for (const date of ['2026-10-28', '2027-10-30']) {
    const now = new Date(`${date}T12:00:00Z`);
    assert.equal(availability({status: 'sold', available_from: '2026-10-30'}, now), 'Sold');
    assert.equal(availability({status: 'temporarily_unavailable', available_from: '2026-10-30'}, now), 'Temporarily Unavailable');
  }
});
test('existing listings default to available and future dates are labelled', () => {
  assert.equal(availability({}), 'Available');
  assert.equal(lusakaDate(new Date('2026-12-31T22:00:00Z')), '2027-01-01');
  assert.match(availabilityLabel({available_from:'2026-10-30'}, new Date('2026-10-28T00:00:00Z')), /30 October 2026/);
});
