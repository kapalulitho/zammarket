export const contactFields = ['whatsapp'];
export function profileInput(values) {
  const result = {};
  for (const [key,max] of Object.entries({username:30,shop_name:60,whatsapp:18})) {
    result[key] = String(values[key] ?? '').trim();
    if (result[key].length > max) throw new Error(`${key.replaceAll('_',' ')} is too long.`);
  }
  result.username = result.username.toLowerCase();
  if (!/^[a-z0-9_]{3,30}$/.test(result.username)) throw new Error('Choose a username with 3–30 letters, numbers, or underscores.');
  if (result.shop_name.length < 3) throw new Error('Enter a public name or shop name of at least 3 characters.');
  result.account_type = values.account_type;
  if (!['individual','business'].includes(result.account_type)) throw new Error('Choose your account type.');
  for (const field of ['whatsapp']) {
    result[field] = result[field].replace(/[ ()-]/g,'');
    // Zambian habit: accept local format (0971234567) and normalise it
    // to international (+260971234567) before the strict check.
    if (/^0\d{9}$/.test(result[field])) result[field] = '+260' + result[field].slice(1);
    else if (/^260\d{9}$/.test(result[field])) result[field] = '+' + result[field];
    if (result[field] && !/^\+[1-9]\d{6,14}$/.test(result[field])) throw new Error('Check the number — for example 0971234567 or +260971234567.');
  }
  // The login email is only for sign-in and is never part of the public profile.
  for (const field of contactFields) result[`show_${field}`] = values[`show_${field}`] === true || values[`show_${field}`] === 'on';
  return result;
}

export function profileAccess(user, profile) {
  if (!user) return 'anonymous';
  if (!user.email_confirmed_at) return 'verify';
  return profile?.completed_at ? 'ready' : 'setup';
}

export function registrationAllowed(settings) {
  return settings?.mailer_autoconfirm === false && settings?.external?.email === true && settings?.disable_signup !== true;
}
