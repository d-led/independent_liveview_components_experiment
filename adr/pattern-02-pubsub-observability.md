# Pattern: PubSub as Observability Backplane

**Also known as:** Byte-Counted Traffic Dashboard, In-Situ PubSub Monitor

## Context

A multi-service cluster communicates over clustered PubSub. Understanding
traffic patterns requires log-diving across nodes. You want live visibility
of: what topics are active, how much data flows per topic, and which services
produce/consume on each.

You don't want to set up Prometheus, Grafana, or OpenTelemetry for a demo.

## Forces

- **No external infra:** No metrics stack for experimental code
- **Live visibility:** See traffic patterns without log-diving
- **Lightweight:** Minimal overhead per message
- **In-situ:** Surface data in the same LiveView the user already sees

## Solution

Track bytes sent and received per PubSub topic in every GenServer and LiveView
state. Expose via LiveView assigns in a traffic dashboard.

```elixir
# On broadcast — measure and increment:
defp broadcast_and_measure(socket, topic, msg) do
  Phoenix.PubSub.broadcast(PubSub, topic, msg)
  bytes = :erlang.term_to_binary(msg) |> byte_size()
  update(socket, :pubsub_sent_bytes, &(&1 + bytes))
end

# On receive (catch-all) — measure all incoming:
def handle_info(msg, state) do
  new_state = %{state | recv_bytes: state.recv_bytes + byte_size_of(msg)}
  {:noreply, new_state}
end

defp byte_size_of(msg), do: :erlang.term_to_binary(msg) |> byte_size()
```

```heex
<%# Dashboard — per-topic breakdown %>
<div>Sent on: <code>global_topic</code>, <code>arrivals</code></div>
<div>Recv from: <code>global_topic</code>, <code>private_clicks:*</code>, ...</div>
<div>Sent: {@pubsub_sent_bytes} bytes | Recv: {@pubsub_recv_bytes} bytes</div>
```

**Source:** `main_app/lib/main_app_web/live/main_live.ex` +
`private_service/lib/private_service/private_click_aggregator_service.ex`

## Resulting Context

- ✓ Zero external infrastructure — just Elixir terms + LiveView assigns
- ✓ Live traffic visibility per topic without log-diving
- ✓ Validates efficiency claims: small Elixir terms vs. HTML blobs
- ✗ Only shows *volume*, not latency, errors, or consumer lag
- ✗ `:erlang.term_to_binary/1` on every message adds CPU overhead
- ✗ Catch-all `handle_info` may double-count in some implementations
- ✗ Not a replacement for a real observability stack in production

## Known Uses

- `independent_liveview_components_experiment`: All 3 services (this repo)

## Related Patterns

- Pattern 01 (Local Rendering): byte counting validates the efficiency claim
