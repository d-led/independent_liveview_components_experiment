# Pattern: Local Rendering with Preloaded Modules

**Also known as:** Spread-Once-Render-Locally, Micro-UI Composition, Bytecode-Delivered Views

## Context

Multiple service teams own independent UI slices. The main app must render
views from other services without compile-time dependencies. Sending
pre-rendered HTML over PubSub is chatty — HTML strings are large and bypass
LiveView's diff engine.

## Forces

- **Team autonomy:** Each team owns its UI slice end-to-end
- **No compile-time coupling:** main_app must not depend on service modules
- **Network efficiency:** Per-event traffic must be minimal
- **Leverage LiveView:** Don't bypass the diff engine

## Solution

Spread view module bytecode once at cluster join. On every event, send only
the small data payload over PubSub. The receiving node renders locally using
the preloaded module via `apply/3`.

```
PrivateClickAggregatorService (private_service node)
  │── on user click ──▶ increments session counter
  └──▶ PubSub.broadcast("private_clicks:sid", %{view: :private, count: N})

MainAppWeb.MainLive (main_app node)
  ├── handle_info(%{view: :private, count: count}, socket)
  │     └─▶ assign(:private_clicks_count, count)
  └── render
        └─▶ apply(PrivateServiceWeb.PrivateClickViews, :render, [assigns])
              ← module bytecode was spread via ModuleSharer at cluster join!
```

**What travels and when:**

| What | When | Size |
|------|------|------|
| BEAM module bytecode | Once, on cluster join | ~KB |
| Event data (`count`, `session_id`) | Per user interaction | Tiny Elixir terms |
| HTML | Never — local render | — |

**Sources:**
- `main_app/lib/main_app_web/live/main_live.ex` — subscriber + renderer
- `private_service/lib/private_service/private_click_aggregator_service.ex` — aggregator
- `private_service/lib/private_service_web/views/private_clicks_view.ex` — view module

## Resulting Context

- ✓ Teams own their UI end-to-end
- ✓ Zero compile-time coupling between services
- ✓ Per-event wire traffic: tiny Elixir terms
- ✓ LiveView diff engine handles DOM updates
- ✓ Graceful degradation: `Code.ensure_loaded?/1` guard
- ✗ Cluster coupling: service down → no new updates (cached bytecode still works)
- ✗ Bytecode version mismatch risk between service deploy and module spread
- ✗ The aggregation in this demo is trivial (a counter) — the architecture
  shines when services do real work (DB access, heavy CPU, independent releases)

## Known Uses

- `independent_liveview_components_experiment`: All 3 services (this repo)
- Pattern extends `ModuleSharer` (Pattern 03) + `Code.ensure_loaded?` guard (Pattern 04)

## References

- Phoenix.LiveView: HEEx rendering, `assign/3`, diff engine
- Erlang `:code` module for bytecode distribution
