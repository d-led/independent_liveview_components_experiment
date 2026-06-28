# Pattern: Presence with Heartbeat Workaround

**Also known as:** Arrivals Hack, Presence Bootstrap, Session-Aware Service

## Context

Phoenix Presence provides CRDT-based distributed session tracking.
Services subscribe to `"presence:lobby"` to know which users are online.
However, in a gossip-based cluster (libcluster), `presence_diff` messages
don't always reach services reliably after a node join or network hiccup.

## Forces

- **Use built-in Presence:** Don't build custom session tracking
- **Reliable delivery:** Services must know about new sessions
- **Gossip cluster:** libcluster's eventual consistency means diffs can be lost
- **Minimal workaround:** Don't rearchitect the whole presence system

## Solution

On LiveView mount, broadcast a lightweight `"hi"` message on a dedicated
`arrivals` topic. Services subscribe to this topic as a *supplementary*
signal. Presence remains the primary mechanism; `arrivals` patches the gap.

```elixir
# main_app mount — after Presence.track, send heartbeat:
def mount(_params, _session, socket) do
  if connected?(socket) do
    MainAppWeb.Presence.track(self(), "presence:lobby", id_of(socket), %{})

    # Workaround: ensure services know about this session
    msg = %{event: "hi", session_id: id_of(socket), timestamp: timestamp()}
    Phoenix.PubSub.broadcast(MainApp.PubSub, "arrivals", msg)
  end
  {:ok, socket}
end
```

```elixir
# Service — handles both presence_diff (primary) AND arrivals (fallback):
def handle_info(%{event: "hi", session_id: session_id} = msg, state) do
  click_count = Map.get(state.sessions, session_id, 0)
  sent = render_one(session_id, click_count)  # ← send current state to new session
  {:noreply, %{state | sent_bytes: state.sent_bytes + sent}}
end

def handle_info(%Broadcast{topic: "presence:lobby", event: "presence_diff",
    payload: %{leaves: leaves, joins: joins}}, state) do
  # Primary mechanism — CRDT-based, works most of the time
  new_sessions = Enum.reduce(joins, state.sessions, fn {sid, _}, acc ->
    Map.put_new(acc, sid, 0)
  end)
  {:noreply, %{state | sessions: new_sessions}}
end
```

**Key properties:**
- `arrivals` is a *supplement*, not a replacement for Presence
- Message is tiny: `%{event: "hi", session_id: sid, timestamp: ts}`
- Service responds by sending current state for that session (idempotent)
- If `presence_diff` already delivered, the `"hi"` is redundant but harmless

**Source:** `main_app/lib/main_app_web/live/main_live.ex` (mount),
`private_service/lib/private_service/private_click_aggregator_service.ex`

## Resulting Context

- ✓ Patches Presence delivery gaps in gossip clusters
- ✓ Minimal overhead — one small message per mount
- ✓ Idempotent — duplicate "hi" messages cause no harm
- ✗ **It's a hack.** The root cause (unreliable presence_diff) remains
- ✗ Adds coupling: services must handle both presence_diff AND arrivals
- ✗ Doesn't fix the underlying libcluster gossip issue

## Known Uses

- `independent_liveview_components_experiment`: All services + main_app (this repo)
- Documented as a known workaround in the repo README

## Related Patterns

- Pattern 01 (Local Rendering): `render_one/2` sends state on "hi"
- Pattern 02 (PubSub Observability): `arrivals` appears in traffic dashboard
