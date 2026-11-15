import ReplyTemplates from './ReplyTemplates';
import { useEffect, useState } from 'react';
import { supabase } from '../supabase';
import { Icon, EmptyArt } from './Design';
import { filterConversations, messageText, sellerReplySuggestions } from '../lib/messageTools';
import { money, listingPhotos } from '../lib/listings';
import { availability } from '../lib/availability';

const whenMessage = value =>
  new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Africa/Lusaka',
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));

export default function Messages({ user, ready, initialConversation, initialDraft = '', onOpenListing, onLogin }) {
  const [conversations, setConversations] = useState([]);
  const [listings, setListings] = useState({});
  const [selected, setSelected] = useState(initialConversation ?? null);
  const [messages, setMessages] = useState([]);
  const [body, setBody] = useState(initialDraft);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [refresh, setRefresh] = useState(0);
  const [hasOlder, setHasOlder] = useState(false);
  const [limit, setLimit] = useState(100);
  const [search, setSearch] = useState('');

  useEffect(() => {
    if (!user || !ready) return;
    let active = true;
    async function load() {
      if (document.hidden) return;
      try {
        const { data, error: failure } = await supabase.from('conversations').select('*')
          .or(`buyer_id.eq.${user.id},seller_id.eq.${user.id}`).order('created_at', { ascending: false });
        if (failure) throw failure;
        if (active) { setConversations(data ?? []); setError(''); }
      } catch { if (active) setError('Unable to load conversations. Please retry.'); }
      finally { if (active) setLoading(false); }
    }
    load();
    const timer = setInterval(load, 5000);
    return () => { active = false; clearInterval(timer); };
  }, [user, ready, refresh]);

  // Product context: one batched lookup for every conversation's listing, so
  // both the inbox and the thread can show what each chat is actually about.
  const conversationKey = conversations.map(item => item.listing_id).join(',');
  useEffect(() => {
    if (!user || !ready) return;
    const ids = [...new Set(conversations.map(item => item.listing_id).filter(Boolean))];
    if (!ids.length) { setListings({}); return; }
    let active = true;
    supabase.from('marketplace_listings')
      .select('id,title,price,image_urls,image_url,status,available_from,deleted_at')
      .in('id', ids)
      .then(({ data }) => {
        if (!active) return;
        const next = {};
        for (const row of data ?? []) next[String(row.id)] = row;
        setListings(next);
      })
      .catch(() => { if (active) setListings({}); });
    return () => { active = false; };
  }, [user, ready, conversationKey]);

  useEffect(() => {
    if (!selected || !user || !ready) return;
    let active = true;
    async function load() {
      if (document.hidden) return;
      try {
        const { data, error: failure } = await supabase.from('messages').select('*')
          .eq('conversation_id', selected).order('created_at', { ascending: false })
          .order('id', { ascending: false }).limit(limit + 1);
        if (failure) throw failure;
        if (active) {
          setHasOlder((data?.length ?? 0) > limit);
          setMessages((data ?? []).slice(0, limit).reverse());
          setError('');
        }
      } catch { if (active) setError('Unable to refresh messages. Please retry.'); }
    }
    load();
    const timer = setInterval(load, 5000);
    return () => { active = false; clearInterval(timer); };
  }, [selected, user, ready, refresh, limit]);

  async function send(event) {
    event.preventDefault();
    if (!body.trim() || sending || !selected || !user || !ready) return;
    setSending(true); setError('');
    try {
      const current = await supabase.auth.getUser();
      if (current.error || current.data.user?.id !== user.id) throw new Error('Session changed');
      const { error: failure } = await supabase.from('messages').insert({
        conversation_id: selected, sender_id: user.id, body: messageText(body),
      });
      if (failure) throw failure;
      setBody(''); setRefresh(value => value + 1);
    } catch { setError('Message could not be confirmed as sent. Check the conversation before retrying.'); }
    finally { setSending(false); }
  }

  if (!user) return <section className="form-page centered-page"><EmptyArt name="message" /><span className="eyebrow">A GOOD CONVERSATION STARTS HERE</span><h1>Find it. Ask about it.</h1>
    <p>Sign in to contact sellers and read your conversations.</p>
    <button className="primary-button" onClick={onLogin}>Sign In</button></section>;
  if (!ready) return <section className="form-page centered-page"><EmptyArt name="message" /><h1>Conversations are coming.</h1>
    <p>We're getting messaging ready. In the meantime, keep exploring local finds.</p></section>;
  const conversation = conversations.find(item => item.id === selected);
  const selectedListing = conversation ? listings[String(conversation.listing_id)] : null;
  return <section className="form-page"><div className="page-icon"><Icon name="message" size={25} /></div><span className="eyebrow">KEEP THE CONVERSATION GOING</span><h1>Your inbox.</h1>
    <p className="muted">Conversations refresh every five seconds.</p>
    {error && <p role="alert">{error} <button onClick={() => setRefresh(value => value + 1)}>Retry</button></p>}
    <div className="messages-layout"><aside aria-label="Conversations">
      <label>Find a conversation<input value={search} onChange={event => setSearch(event.target.value)} placeholder="Search product titles" /></label>
      {loading ? <p role="status">Loading conversations...</p> : !conversations.length && <p>No conversations yet. Open a listing and choose Message Seller.</p>}
      {filterConversations(conversations, search).map(item => {
        const row = listings[String(item.listing_id)];
        const photo = row ? listingPhotos(row)[0] : null;
        return <button className="conversation-button" key={item.id}
          disabled={sending} aria-pressed={selected === item.id} onClick={() => { setSelected(item.id); setMessages([]); setBody(''); setLimit(100); }}>
          <span className="conversation-thumb" aria-hidden="true">
            {photo ? <img src={photo} alt="" loading="lazy" /> : <Icon name="bag" size={18} />}
          </span>
          <span className="conversation-copy">
            {item.listing_title}
            <small>{item.seller_id === user.id ? 'Buyer enquiry' : 'Seller conversation'}</small>
          </span>
        </button>;
      })}
    </aside><div>
      {selected ? <><h2>{conversation?.listing_title ?? 'Conversation'}</h2>
        {conversation?.listing_id && (selectedListing ? (
          <article className="message-listing">
            <span className="message-listing-photo" aria-hidden="true">
              {listingPhotos(selectedListing)[0]
                ? <img src={listingPhotos(selectedListing)[0]} alt="" loading="lazy" />
                : <Icon name="bag" size={20} />}
            </span>
            <span className="message-listing-body">
              <strong>{selectedListing.title}</strong>
              <span className="my-listing-meta">
                {selectedListing.price != null && <span>{money(selectedListing.price)}</span>}
                <span
                  className={`availability-badge status-${availability(selectedListing).toLowerCase().replaceAll(' ', '-')}`}
                >
                  {availability(selectedListing)}
                </span>
              </span>
            </span>
            {onOpenListing && (
              <button className="text-button" onClick={() => onOpenListing(selectedListing)}>
                View listing
              </button>
            )}
          </article>
        ) : (
          <p className="muted">This listing is no longer available, but the conversation is kept.</p>
        ))}
        {hasOlder && <button onClick={() => setLimit(value => value + 100)}>Load older messages</button>}
        <div className="message-history" role="log" aria-label="Conversation messages" aria-live="polite">
          {messages.map(message => <div className={`message ${message.sender_id === user.id ? 'mine' : ''}`} key={message.id}>
            <strong>{message.sender_id === user.id ? 'You' : conversation?.seller_id === message.sender_id ? 'Seller' : 'Buyer'}</strong>
            <p>{message.body}</p><small>{whenMessage(message.created_at)} (Zambia)</small>
          </div>)}
          {!messages.length && <p>No messages yet.</p>}
        </div>
        {conversation?.seller_id === user.id && <details><summary>Quick reply suggestions</summary><p>These only fill the message box. Review before sending.</p>{sellerReplySuggestions.map(text => <button className="text-button" type="button" key={text} disabled={sending} onClick={() => setBody(text)}>{text}</button>)}</details>}
        <ReplyTemplates key={user.id} onUse={setBody} disabled={sending} /><form onSubmit={send}><label>Message<textarea required maxLength={4000} value={body} onChange={event => setBody(event.target.value)} /></label><small>{body.length}/4,000 characters</small>
          <button className="primary-button" disabled={sending || !body.trim()}>{sending ? 'Sending...' : 'Send message'}</button></form>
      </> : <p>Select a conversation.</p>}
    </div></div>
  </section>;
}
