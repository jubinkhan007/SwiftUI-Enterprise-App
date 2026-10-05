import test from 'node:test';
import assert from 'node:assert/strict';

// Business logic helpers for Subscription & Billing

export function calculateSeatUsage(memberCount, tier = 'free') {
  const normalizedTier = (tier || 'free').toLowerCase();
  const isFree = normalizedTier === 'free';
  const limit = isFree ? 5 : 9999;
  const isUnlimited = !isFree;
  const percentage = isFree 
    ? Math.min(100, Math.round((memberCount / limit) * 100))
    : Math.min(100, Math.round((memberCount / 100) * 100));
  
  const isNearLimit = isFree && memberCount >= 4;
  const isAtOrExceededLimit = isFree && memberCount >= limit;

  return {
    memberCount,
    limit,
    isUnlimited,
    percentage,
    isNearLimit,
    isAtOrExceededLimit,
    displayLabel: isFree ? `${memberCount} / 5 seats used` : `${memberCount} used (Unlimited)`
  };
}

export function calculateStorageUsage(storageUsedMB, tier = 'free') {
  const normalizedTier = (tier || 'free').toLowerCase();
  let limitMB = 100;
  let displayLimit = '100 MB';

  if (normalizedTier === 'enterprise') {
    limitMB = 512000;
    displayLimit = '500 GB';
  } else if (normalizedTier === 'pro') {
    limitMB = 51200;
    displayLimit = '50 GB';
  }

  const fraction = Math.min(1.0, storageUsedMB / limitMB);
  const percentage = Math.min(100, Math.round(fraction * 100));

  return {
    storageUsedMB,
    limitMB,
    displayLimit,
    fraction,
    percentage,
    displayString: `${storageUsedMB.toFixed(1)} MB / ${displayLimit}`
  };
}

export function calculateProjectUsage(projectCount, tier = 'free') {
  const normalizedTier = (tier || 'free').toLowerCase();
  const isFree = normalizedTier === 'free';
  const limit = isFree ? 1 : 9999;
  const isAtLimit = isFree && projectCount >= limit;

  return {
    projectCount,
    limit,
    isUnlimited: !isFree,
    isAtLimit,
    displayLabel: isFree ? `${projectCount} / 1 project used` : `${projectCount} active (Unlimited)`
  };
}

export function getPlanTierDetails(tier = 'free') {
  const normalized = (tier || 'free').toLowerCase();
  switch (normalized) {
    case 'pro':
      return {
        name: 'Pro',
        priceMonthly: 19,
        memberLimit: 'Unlimited',
        storageLimit: '50 GB',
        projectLimit: 'Unlimited',
        hasVideoCalling: true,
        hasWebhooks: true,
        hasSSO: false,
        hasAuditLog: false
      };
    case 'enterprise':
      return {
        name: 'Enterprise',
        priceMonthly: 99,
        memberLimit: 'Unlimited',
        storageLimit: '500 GB',
        projectLimit: 'Unlimited',
        hasVideoCalling: true,
        hasWebhooks: true,
        hasSSO: true,
        hasAuditLog: true
      };
    case 'free':
    default:
      return {
        name: 'Free',
        priceMonthly: 0,
        memberLimit: '5',
        storageLimit: '100 MB',
        projectLimit: '1',
        hasVideoCalling: false,
        hasWebhooks: false,
        hasSSO: false,
        hasAuditLog: false
      };
  }
}

export function parseBillingRedirectParams(searchParamsString) {
  const params = new URLSearchParams(searchParamsString || '');
  if (params.get('mock_checkout') === 'success' || params.get('stripe_session_id')) {
    return {
      type: 'checkout_success',
      message: 'Payment successful! Your workspace has been upgraded to the Pro Plan.'
    };
  }
  if (params.get('mock_portal') === 'downgrade') {
    return {
      type: 'portal_downgrade',
      message: 'Subscription updated via customer portal.'
    };
  }
  return null;
}

export function validateBillingResponse(resp) {
  if (!resp || typeof resp !== 'object') {
    return { valid: false, error: 'Empty or invalid response object' };
  }
  const url = resp.url || (resp.data && resp.data.url);
  if (!url || typeof url !== 'string') {
    return { valid: false, error: 'Missing redirect URL in billing response' };
  }
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    return { valid: false, error: 'Redirect URL must be an HTTP/HTTPS address' };
  }
  return { valid: true, url };
}

// Tests

test('Seat Usage: correctly calculates Free plan limits and warnings', () => {
  const normalUsage = calculateSeatUsage(2, 'free');
  assert.equal(normalUsage.memberCount, 2);
  assert.equal(normalUsage.limit, 5);
  assert.equal(normalUsage.isUnlimited, false);
  assert.equal(normalUsage.percentage, 40);
  assert.equal(normalUsage.isNearLimit, false);
  assert.equal(normalUsage.isAtOrExceededLimit, false);

  const nearLimitUsage = calculateSeatUsage(4, 'free');
  assert.equal(nearLimitUsage.percentage, 80);
  assert.equal(nearLimitUsage.isNearLimit, true);
  assert.equal(nearLimitUsage.isAtOrExceededLimit, false);

  const maxLimitUsage = calculateSeatUsage(5, 'free');
  assert.equal(maxLimitUsage.percentage, 100);
  assert.equal(maxLimitUsage.isNearLimit, true);
  assert.equal(maxLimitUsage.isAtOrExceededLimit, true);
});

test('Seat Usage: Pro and Enterprise plans have unlimited members without warning', () => {
  const proUsage = calculateSeatUsage(25, 'pro');
  assert.equal(proUsage.isUnlimited, true);
  assert.equal(proUsage.isNearLimit, false);
  assert.equal(proUsage.isAtOrExceededLimit, false);
  assert.match(proUsage.displayLabel, /Unlimited/);

  const entUsage = calculateSeatUsage(120, 'enterprise');
  assert.equal(entUsage.isUnlimited, true);
  assert.equal(entUsage.isNearLimit, false);
});

test('Storage Usage: correctly computes capacities across tiers', () => {
  const freeStorage = calculateStorageUsage(4.5, 'free');
  assert.equal(freeStorage.limitMB, 100);
  assert.equal(freeStorage.displayLimit, '100 MB');
  assert.equal(freeStorage.percentage, 5);
  assert.equal(freeStorage.displayString, '4.5 MB / 100 MB');

  const proStorage = calculateStorageUsage(4.5, 'pro');
  assert.equal(proStorage.limitMB, 51200);
  assert.equal(proStorage.displayLimit, '50 GB');
  assert.equal(proStorage.displayString, '4.5 MB / 50 GB');

  const entStorage = calculateStorageUsage(100.0, 'enterprise');
  assert.equal(entStorage.limitMB, 512000);
  assert.equal(entStorage.displayLimit, '500 GB');
  assert.equal(entStorage.displayString, '100.0 MB / 500 GB');
});

test('Project Usage: enforces single project on Free plan', () => {
  const freeProjects = calculateProjectUsage(1, 'free');
  assert.equal(freeProjects.isAtLimit, true);
  assert.equal(freeProjects.isUnlimited, false);

  const proProjects = calculateProjectUsage(15, 'pro');
  assert.equal(proProjects.isAtLimit, false);
  assert.equal(proProjects.isUnlimited, true);
});

test('Plan Tier Specs: returns correct prices, capabilities and restrictions', () => {
  const free = getPlanTierDetails('free');
  assert.equal(free.priceMonthly, 0);
  assert.equal(free.hasVideoCalling, false);
  assert.equal(free.hasWebhooks, false);
  assert.equal(free.hasSSO, false);

  const pro = getPlanTierDetails('pro');
  assert.equal(pro.priceMonthly, 19);
  assert.equal(pro.hasVideoCalling, true);
  assert.equal(pro.hasWebhooks, true);
  assert.equal(pro.hasSSO, false);

  const enterprise = getPlanTierDetails('enterprise');
  assert.equal(enterprise.priceMonthly, 99);
  assert.equal(enterprise.hasVideoCalling, true);
  assert.equal(enterprise.hasWebhooks, true);
  assert.equal(enterprise.hasSSO, true);
  assert.equal(enterprise.hasAuditLog, true);
});

test('Redirect Query Params: parses checkout and portal return states', () => {
  const checkoutSuccess = parseBillingRedirectParams('?mock_checkout=success&org_id=123');
  assert.equal(checkoutSuccess?.type, 'checkout_success');
  assert.match(checkoutSuccess?.message, /Pro Plan/);

  const stripeSession = parseBillingRedirectParams('?stripe_session_id=cs_test_abc123');
  assert.equal(stripeSession?.type, 'checkout_success');

  const portalDowngrade = parseBillingRedirectParams('?mock_portal=downgrade');
  assert.equal(portalDowngrade?.type, 'portal_downgrade');
  assert.match(portalDowngrade?.message, /customer portal/);

  assert.equal(parseBillingRedirectParams('?other=value'), null);
  assert.equal(parseBillingRedirectParams(''), null);
});

test('Billing Response: validates checkout and portal URL payloads', () => {
  const validResp = { success: true, url: 'https://checkout.stripe.com/pay/cs_test_123' };
  assert.deepEqual(validateBillingResponse(validResp), {
    valid: true,
    url: 'https://checkout.stripe.com/pay/cs_test_123'
  });

  const nestedResp = { success: true, data: { url: 'https://billing.stripe.com/p/session/123' } };
  assert.deepEqual(validateBillingResponse(nestedResp), {
    valid: true,
    url: 'https://billing.stripe.com/p/session/123'
  });

  const invalidUrl = { success: true, url: 'ftp://bad-url' };
  assert.equal(validateBillingResponse(invalidUrl).valid, false);

  const missingUrl = { success: true };
  assert.equal(validateBillingResponse(missingUrl).valid, false);
});
