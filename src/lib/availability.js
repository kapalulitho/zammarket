
export function lusakaDate(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Lusaka',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).formatToParts(now);

  const getValue = function (type) {
    const part = parts.find(function (item) {
      return item.type === type;
    });

    return part ? part.value : '';
  };

  return getValue('year') + '-' +
    getValue('month') + '-' +
    getValue('day');
}

export function availability(listing, now = new Date()) {
  if (listing.status === 'sold') {
    return 'Sold';
  }

  if (listing.status === 'temporarily_unavailable') {
    return 'Temporarily Unavailable';
  }

  if (
    listing.available_from &&
    listing.available_from > lusakaDate(now)
  ) {
    return 'Coming Soon';
  }

  return 'Available';
}

export function availabilityLabel(listing, now = new Date()) {
  const status = availability(listing, now);

  if (status !== 'Coming Soon') {
    return status;
  }

  const date = new Date(
    listing.available_from + 'T00:00:00+02:00'
  );

  const formattedDate = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Lusaka',
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  }).format(date);

  return 'Coming Soon — Available from ' + formattedDate;
}

export function marketplaceFeedListings(items = []) {
  return items.filter(function (item) {
    return item.status !== 'sold' && !item.deleted_at;
  });
}

export function isSoldHistoryArchived(listing, now = new Date()) {
  if (listing.status !== 'sold' || !listing.sold_at) {
    return false;
  }

  const soldTime = Date.parse(listing.sold_at);

  if (!Number.isFinite(soldTime)) {
    return false;
  }

  const sevenDays = 7 * 24 * 60 * 60 * 1000;

  return now.getTime() >= soldTime + sevenDays;
}

export function sortFeedListings(
  items,
  sort = 'recommended',
  now = new Date()
) {
  const rank = {
    'Available': 0,
    'Coming Soon': 1,
    'Temporarily Unavailable': 2,
    'Sold': 3
  };

  return [...items].sort(function (a, b) {
    if (sort === 'low') {
      return Number(a.price) - Number(b.price);
    }

    if (sort === 'high') {
      return Number(b.price) - Number(a.price);
    }

    if (sort === 'recommended') {
      const difference =
        rank[availability(a, now)] -
        rank[availability(b, now)];

      if (difference !== 0) {
        return difference;
      }
    }

    return (
      (Date.parse(b.created_at) || 0) -
      (Date.parse(a.created_at) || 0)
    );
  });
}
