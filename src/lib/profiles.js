export const contactFields = ['whatsapp','phone','public_email','location','address'];
export function profileInput(values, loginEmail = '') {
  const result = {};
  for (const [key,max] of Object.entries({username:30,shop_name:60,whatsapp:18,phone:18,public_email:254,location:120,address:300})) {
    result[key] = String(values[key] ?? '').trim();
    if (result[key].length > max) throw new Error(`${key.replaceAll('_',' ')} is too long.`);
  }
  result.username = result.username.toLowerCase();
  if (!/^[a-z0-9_]{3,30}$/.test(result.username)) throw new Error('Choose a username with 3–30 letters, numbers, or underscores.');
  if (result.shop_name.length < 3) throw new Error('Enter a public name or shop name of at least 3 characters.');
  result.account_type = values.account_type;
  if (!['individual','business'].includes(result.account_type)) throw new Error('Choose your account type.');
  for (const field of ['whatsapp','phone']) {
    result[field] = result[field].replace(/[ ()-]/g,'');
    if (result[field] && !/^\+[1-9]\d{6,14}$/.test(result[field])) throw new Error('Use an international phone number, for example +260971234567.');
  }
  if (result.public_email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(result.public_email)) throw new Error('Enter a valid public contact email.');
  if (result.public_email && result.public_email.toLowerCase() === loginEmail.trim().toLowerCase()) throw new Error('Use a different public contact email to keep your login email private.');
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
