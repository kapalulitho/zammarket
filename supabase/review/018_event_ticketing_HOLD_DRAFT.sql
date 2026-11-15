-- HOLD / REVIEW ONLY. Requires 013_v2 community_entries; NOT an upgrade for original 013.
-- Reservations remain disabled. No payments, tickets/QR issuance or expiry job activated.
BEGIN;
SET LOCAL lock_timeout='5s';SET LOCAL statement_timeout='60s';
CREATE TABLE public.ticket_operation_settings(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),enabled boolean NOT NULL DEFAULT false);
INSERT INTO public.ticket_operation_settings VALUES(true,false);ALTER TABLE public.ticket_operation_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ticket_operation_settings FROM public,anon,authenticated,service_role;GRANT SELECT,UPDATE(enabled) ON public.ticket_operation_settings TO service_role;
CREATE TABLE public.event_ticket_categories(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),event_id uuid NOT NULL REFERENCES public.community_entries(id),
 label text NOT NULL CHECK(length(trim(label)) BETWEEN 2 AND 80),price_minor bigint NOT NULL CHECK(price_minor BETWEEN 0 AND 100000000),
 currency text NOT NULL DEFAULT 'ZMW' CHECK(currency='ZMW'),capacity integer NOT NULL CHECK(capacity BETWEEN 1 AND 100000),
 allocated integer NOT NULL DEFAULT 0 CHECK(allocated>=0),active boolean NOT NULL DEFAULT false,CHECK(allocated<=capacity),UNIQUE(event_id,label)
);
CREATE TABLE public.event_reservations(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),event_id uuid NOT NULL REFERENCES public.community_entries(id),buyer_id uuid NOT NULL REFERENCES auth.users(id),
 organiser_id uuid NOT NULL REFERENCES auth.users(id),category_id uuid NOT NULL REFERENCES public.event_ticket_categories(id),
 quantity integer NOT NULL CHECK(quantity BETWEEN 1 AND 20),unit_price_minor bigint NOT NULL CHECK(unit_price_minor>=0),
 currency text NOT NULL DEFAULT 'ZMW' CHECK(currency='ZMW'),state text NOT NULL DEFAULT 'held' CHECK(state IN('held','cancelled')),
 cancelled_at timestamptz,cancelled_by uuid REFERENCES auth.users(id),idempotency_key uuid NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(buyer_id,idempotency_key)
);
CREATE INDEX ticket_event_idx ON public.event_ticket_categories(event_id);
CREATE INDEX reservation_buyer_idx ON public.event_reservations(buyer_id,created_at DESC);
CREATE INDEX reservation_organiser_idx ON public.event_reservations(organiser_id,created_at DESC);
ALTER TABLE public.event_ticket_categories ENABLE ROW LEVEL SECURITY;ALTER TABLE public.event_reservations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.event_ticket_categories,public.event_reservations FROM public,anon,authenticated,service_role;
GRANT SELECT ON public.event_ticket_categories TO anon,authenticated;GRANT SELECT ON public.event_reservations TO authenticated;
GRANT SELECT,INSERT,UPDATE(label,price_minor,capacity,active) ON public.event_ticket_categories TO service_role;
CREATE POLICY ticket_category_read ON public.event_ticket_categories FOR SELECT TO anon,authenticated USING(EXISTS(SELECT 1 FROM public.community_entries e WHERE e.id=event_id AND e.kind='event' AND ((e.status='published' AND active) OR e.owner_id=(SELECT auth.uid()))));
CREATE POLICY reservation_participants ON public.event_reservations FOR SELECT TO authenticated USING((SELECT auth.uid()) IN(buyer_id,organiser_id));
CREATE FUNCTION public.reserve_event_tickets(p_category uuid,p_quantity integer,p_key uuid) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid();category public.event_ticket_categories;event public.community_entries;prior public.event_reservations;reservation_id uuid;
BEGIN
 IF caller IS NULL OR NOT public.marketplace_complete_member() THEN RAISE EXCEPTION 'Verified completed account required'; END IF;
 IF NOT coalesce((SELECT enabled FROM public.ticket_operation_settings WHERE singleton),false) THEN RAISE EXCEPTION 'Ticket reservations are disabled'; END IF;
 IF p_key IS NULL OR p_quantity IS NULL OR p_quantity NOT BETWEEN 1 AND 20 THEN RAISE EXCEPTION 'Invalid reservation'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended('ticket-buyer:'||caller::text,0));
 PERFORM pg_advisory_xact_lock(hashtextextended('ticket:'||caller::text||p_key::text,0));
 SELECT * INTO prior FROM public.event_reservations WHERE buyer_id=caller AND idempotency_key=p_key;
 IF prior.id IS NOT NULL THEN IF prior.category_id<>p_category OR prior.quantity<>p_quantity THEN RAISE EXCEPTION 'Idempotency key reused'; END IF;RETURN prior.id;END IF;
 SELECT * INTO category FROM public.event_ticket_categories WHERE id=p_category FOR UPDATE;
 SELECT * INTO event FROM public.community_entries WHERE id=category.event_id FOR SHARE;
 IF category.id IS NULL OR event.id IS NULL OR event.kind<>'event' OR event.status<>'published' OR event.starts_at<=now() OR event.owner_id=caller OR NOT category.active OR category.allocated+p_quantity>category.capacity THEN RAISE EXCEPTION 'Tickets unavailable'; END IF;
 IF coalesce((SELECT sum(quantity) FROM public.event_reservations WHERE buyer_id=caller AND event_id=event.id AND state='held'),0)+p_quantity>20 THEN RAISE EXCEPTION 'At most twenty held tickets per event'; END IF;
 UPDATE public.event_ticket_categories SET allocated=allocated+p_quantity WHERE id=p_category;
 INSERT INTO public.event_reservations(event_id,buyer_id,organiser_id,category_id,quantity,unit_price_minor,idempotency_key) VALUES(event.id,caller,event.owner_id,p_category,p_quantity,category.price_minor,p_key) RETURNING id INTO reservation_id;
 RETURN reservation_id;
END $$;
CREATE FUNCTION public.cancel_event_reservation(p_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE caller uuid:=auth.uid();reservation public.event_reservations;category_id_value uuid;
BEGIN
 -- Cancellation can release a prior hold while new reservations are disabled.
 SELECT category_id INTO category_id_value FROM public.event_reservations WHERE id=p_id AND caller IN(buyer_id,organiser_id);
 IF caller IS NULL OR category_id_value IS NULL THEN RAISE EXCEPTION 'Reservation unavailable'; END IF;
 PERFORM id FROM public.event_ticket_categories WHERE id=category_id_value FOR UPDATE;
 SELECT * INTO reservation FROM public.event_reservations WHERE id=p_id FOR UPDATE;
 IF reservation.state='cancelled' THEN RETURN; END IF;
 UPDATE public.event_reservations SET state='cancelled',cancelled_at=now(),cancelled_by=caller WHERE id=p_id;
 UPDATE public.event_ticket_categories SET allocated=allocated-reservation.quantity WHERE id=reservation.category_id;
END $$;
REVOKE ALL ON FUNCTION public.reserve_event_tickets(uuid,integer,uuid),public.cancel_event_reservation(uuid) FROM public,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.reserve_event_tickets(uuid,integer,uuid),public.cancel_event_reservation(uuid) TO authenticated;
COMMIT;
