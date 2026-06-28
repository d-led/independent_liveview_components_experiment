# Pattern: Graceful Degradation via ensure_loaded?

**Also known as:** Optional Dependency Guard, Late-Binding Render, Fallback UI

## Context

A LiveView renders UI components from modules that may not be loaded yet
(spread via ModuleSharer at cluster join time). During startup, before the
first module sync, or when a service is down, these modules are absent.

You want the UI to show a meaningful fallback rather than crashing.

## Forces

- **Non-blocking startup:** Don't delay render waiting for modules
- **No compile-time dependency:** Cannot use `import` or `alias`
- **Live update:** When module arrives, UI should update without page reload
- **Graceful:** Never show a raw crash to the user

## Solution

Use `Code.ensure_loaded?/1` as a conditional guard in the template. Use
`apply/3` for late-bound rendering. When the module is absent, show a
placeholder. When the `"modules:new:local"` PubSub event arrives, the
LiveView re-renders automatically (the assign changes).

```heex
<%# main_app render — no compile-time dependency on PrivateServiceWeb %>
<%= if Code.ensure_loaded?(PrivateServiceWeb.PrivateClickViews) and @private_clicks_count do %>
  {apply(PrivateServiceWeb.PrivateClickViews, :render, [
    %{count: @private_clicks_count, session_id: @session_id}
  ])}
<% else %>
  <p class="text-gray-400">Waiting for Sessions service component...</p>
<% end %>
```

```elixir
# When a new module arrives, re-render happens automatically:
def handle_info({:new_module_local, _mod}, socket) do
  # socket re-renders — this time ensure_loaded? returns true
  {:noreply, socket}
end
```

**Key properties:**
- `Code.ensure_loaded?/1` is a VM-level check — no try/catch needed
- `apply/3` calls the module dynamically — no compile-time coupling
- Fallback text is pure HEEx — no special error handling
- Re-render is automatic when assigns change

**Source:** `main_app/lib/main_app_web/live/main_live.ex` (render function)

## Resulting Context

- ✓ Zero compile-time coupling between services
- ✓ Graceful fallback during startup and service outages
- ✓ Automatic recovery when module arrives
- ✓ Simple — one conditional, no error recovery framework
- ✗ Fallback is static text — could be richer (spinner, skeleton)
- ✗ `apply/3` bypasses Dialyzer — runtime errors if module API changes

## Known Uses

- `independent_liveview_components_experiment`: main_app render (this repo)
- Any Elixir system with optional/late-bound module dependencies

## Related Patterns

- Pattern 01 (Local Rendering): the `apply/3` call this guards
- Pattern 03 (Bidirectional Module Sync): delivers the modules this pattern waits for
