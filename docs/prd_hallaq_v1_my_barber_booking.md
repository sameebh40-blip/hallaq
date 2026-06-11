---
title: HALLAQ V1 PRD — Booking + My Barber
product: Hallaq
version: v1
date: 2026-06-02
---

# 1) Summary

Hallaq V1 ships the core loop that makes customers say “I’m on Hallaq”: **discover a barber, set them as “My Barber”, and rebook in seconds**. The feature turns Hallaq from a one-time booking tool into a loyalty engine with a premium, high-trust experience.

This PRD focuses on the V1 priority scope: **Booking + My Barber**. The wider “Domination System” items are captured as V1.1+ backlog to keep execution tight.

# 2) Goals

- Make rebooking effortless with a single, prominent “Book Again” CTA.
- Increase retention by establishing a primary barber relationship (“My Barber”).
- Increase trust with clear availability, service pricing, and confirmation states.
- Support one codebase delivering web + mobile experiences (Flutter).

# 3) Non-Goals (V1)

- Payments (BenefitPay, cards) as a required step to book.
- Multi-barber “My Barbers” list (V1 supports one pinned barber).
- Full slot-based scheduling engine (V1 supports time suggestions + booking requests; slot precision can be phased).
- Marketplace, academy, AI hair preview, home service.

# 4) Target Users & Personas

- Customer
  - Wants a consistent look and fast rebooking.
  - Values trust signals and clear confirmation.
- Barber
  - Wants more repeat customers, less back-and-forth, and a stronger personal brand.
- Shop Owner (secondary in V1 scope)
  - Wants better utilization and visibility for staff.

# 5) Current System (Existing Repo Alignment)

Hallaq already contains:

- Flutter app with role-based screens (customer/barber/shop/admin).
- Supabase backend with:
  - `profiles` (roles)
  - `barbers`, `barbershops`, `services`
  - `bookings` with statuses `pending/accepted/rejected/cancelled/completed`
  - `offers`, `notifications`
  - Working hours + time off tables: `barber_working_hours`, `barber_time_off`, `shop_working_hours`

V1 should reuse these primitives instead of introducing parallel systems.

# 6) Core User Journeys

## 6.1 Customer sets “My Barber”

1. Customer lands on a barber profile.
2. Taps “Set as My Barber”.
3. Home screen now shows “Your Barber” module with:
   - Barber name + avatar
   - Next available time
   - “Book Again” primary CTA

## 6.2 Customer rebooks in seconds

1. From Home “Your Barber” module, tap “Book Again”.
2. New booking screen opens pre-filled with:
   - Barber
   - Last booked service (if available)
   - Suggested next time(s)
3. Customer confirms.
4. Booking enters `pending` state and customer sees confirmation UI.

## 6.3 Barber responds

1. Barber dashboard shows incoming booking requests.
2. Barber accepts/rejects.
3. Customer receives notification and booking updates.

# 7) Functional Requirements

## 7.1 “My Barber” Relationship

### Requirements

- Customer can assign exactly one barber as “My Barber”.
- Customer can change “My Barber” (with confirmation).
- Customer can remove “My Barber”.
- “My Barber” persists across devices (stored server-side).

### Data model (recommended)

Use one of these approaches:

- Option A (recommended for V1): add `profiles.my_barber_id uuid null references barbers(id)`
  - Simple, fast for Home screen.
  - Keeps “primary barber” separate from follows/likes.
- Option B: reuse existing social tables (`follows`) and add a `is_primary` flag
  - Better long-term if “following” becomes core, but slightly more involved.

Acceptance criteria:

- When customer sets a My Barber, Home screen shows the module within the next app session without any local caching hacks.
- When My Barber is removed, Home screen falls back to discovery content (no empty module).

## 7.2 Home Screen: “Your Barber” Module

### UI content (minimal text, premium)

- Title: “Your Barber”
- Barber identity: name + photo
- Availability line: “Next Available: Today 7 PM” (localized)
- Primary CTA: “Book Again”
- Secondary actions (optional V1): “View Profile”, “Change”

Acceptance criteria:

- Exactly one main CTA in the module (“Book Again”).
- Module loads in < 1 second on a warm session (perceived performance target) by using a single backend query or cached profile snapshot.

## 7.3 Next Available Time (V1 algorithm)

V1 provides a trustworthy “next available” indicator without needing a full scheduling engine.

### Inputs

- Barber working hours (`barber_working_hours`)
- Barber time off (`barber_time_off`)
- Existing accepted bookings for that barber (if stored with a time window)
- Current time in Bahrain timezone

### Suggested V1 logic

- If the barber has `queue_status.is_open = true`, show “Available Now”.
- Else compute the next working interval:
  - Find the earliest enabled working-hours window from now → +7 days.
  - Exclude windows that fall entirely inside time off.
  - If bookings have start/end timestamps, exclude booked times; otherwise, show start of window as “next available” and keep booking as request-based.

Acceptance criteria:

- Must never show an availability time in the past.
- Must handle timezone correctly (Bahrain).
- If unavailable within 7 days, show “No availability this week” and switch CTA to “Request a time”.

## 7.4 Book Again

### Behavior

- “Book Again” opens booking flow with the barber preselected.
- Default service: customer’s most recent completed booking service with that barber (fallback: barber’s top service).
- Default time:
  - Use “Next Available” suggestion if available.
  - Else allow the customer to pick a preferred time range (e.g., Today evening / Tomorrow morning).

### Booking states

- Create: inserts a new row in `bookings` with `status = pending`.
- Update: barber later accepts/rejects; customer sees state change.

Acceptance criteria:

- From Home to booking confirmation in ≤ 3 taps.
- Customer can complete a booking request without entering any free text (optional message is allowed).

## 7.5 Personalized Feed & Offers (Minimal V1)

### Personalized feed (V1)

- Home feed prioritizes:
  - My Barber content (portfolio items / reels)
  - Offers from My Barber (if offers exist)
  - Fallback to Explore content

### Special offers (V1)

- If My Barber has active offers, show a compact “Special Offer” card above the fold (no heavy copy).

Acceptance criteria:

- Offers do not block booking CTA.
- Customer can hide/dismiss an offer card for the session.

## 7.6 Reminders & New Haircut Alerts (V1)

### Appointment reminders

- On booking accepted:
  - Send notification instantly: “Confirmed”
  - Send reminder: 24 hours before (if feasible with current infrastructure)

### New haircut alerts

- When My Barber posts a new portfolio item/reel:
  - Notification is created for followers / My Barber customers (V1 can limit to My Barber only).

Acceptance criteria:

- Notifications are visible in the in-app notifications screen.
- If background push is not ready, in-app notifications still work.

# 8) Edge Cases

- Customer has no My Barber: Home shows discovery-focused layout.
- My Barber is deleted/disabled: relationship is cleared and customer is prompted to choose another barber.
- Customer changes My Barber: previous barber content de-prioritizes immediately.
- Barber has no working hours configured: show “Schedule not available” and allow “Request a time”.
- Double booking / race conditions: backend must prevent conflicting accepted bookings if time windows are enforced.

# 9) UX / Brand Requirements (Hard Rules)

- Premium black theme with luxury gold accents and glassmorphism.
- Large imagery, minimal text, strong contrast.
- One main CTA per screen (or per module, where applicable).
- Smooth animations; transitions should feel “luxury startup”.
- Typography hierarchy: big titles, compact metadata.

# 10) Metrics (V1)

- My Barber adoption rate: % of active customers who set a My Barber.
- Rebooking rate: % of bookings created via Book Again.
- Time-to-book: median time from Home open → booking created.
- Conversion: booking pending → accepted.
- Retention: D7/D30 returning customers with My Barber vs without.

# 11) Rollout Plan

- Phase 0 (internal): enable My Barber for test users, validate booking flow.
- Phase 1 (public beta): ship Home module + Book Again + basic availability.
- Phase 2: reminders + stronger personalization + refined availability engine.

# 12) Backlog (V1.1+)

- Barber Digital Card export (PNG/PDF) + share sheet.
- QR profile system (public URL) + QR download area.
- Haircut inspiration hub (browse by style).
- Event Ready (wedding/events premium section).
- Hallaq Score (0–100) + response time + seen-by social proof.
- Customer transformations gallery.
- Ambassador program + awards system expansions.
- Bahrain map discovery (dark premium map) and Top 10 rankings pages.
