// All identity comes from Supabase Auth. No separate login flag is persisted.
export function createAuthSession(auth, onChange) {
  let active = true;
  let revision = 0;
  let current = {status:'loading',user:null,error:''};
  const emit = next => {if (active) {current = next; onChange(next);}};
  const apply = (user, reason) => emit({status:user ? 'authenticated' : 'anonymous',user:user ?? null,error:'',reason});
  const {data} = auth.onAuthStateChange((event,session) => {
    if (!active || event === 'INITIAL_SESSION') return;
    revision++;
    if (event === 'SIGNED_OUT' || !session?.user) apply(null,'signout');
    else apply(session.user,event === 'SIGNED_IN' && current.user?.id !== session.user.id ? 'signin' : 'session');
  });
  async function restore() {
    const request = ++revision;
    emit({status:'loading',user:null,error:''});
    try {
      const {data: sessionData,error} = await auth.getSession();
      if (error) throw error;
      if (!active || request !== revision) return;
      if (!sessionData.session) {apply(null,'restore'); return;}
      // Validate a restored identity with Auth rather than trusting cached user data.
      const {data: userData,error: userError} = await auth.getUser();
      if (!active || request !== revision) return;
      if (userError || !userData.user) throw userError ?? new Error('Session unavailable');
      apply(userData.user,'restore');
    } catch {
      if (active && request === revision) emit({status:'error',user:null,error:'We couldn’t verify your session. Check your connection and try again.'});
    }
  }
  restore();
  return {
    retry:restore,
    async signOut() {
      const {error} = await auth.signOut({scope:'local'});
      if (error) throw error;
      revision++;
      apply(null,'signout');
    },
    stop() {active = false; revision++; data.subscription.unsubscribe();},
  };
}
