# Pattern: Bidirectional Module Sync

**Also known as:** ModuleSharer, Pull-and-Push Bytecode Sync, Symmetric Module Gossip

## Context

In a multi-service cluster where each service owns different view modules,
a new node joining needs modules from ALL existing nodes — not just its own.
The ssr-robust-live-svg pattern (push on `:nodeup`) only spreads *its own*
modules. Here, every node needs to both push its modules AND pull from others.

## Forces

- **Bidirectional:** New node needs existing modules; existing nodes need new ones
- **Symmetric:** Every node is both producer and consumer of module bytecode
- **Startup race:** A node may join before PubSub subscriptions are ready
- **Deduplication:** Don't reload modules already present

## Solution

On init, send a `:request_sync` message. Other nodes respond by broadcasting
their prepared modules. On `:nodeup`, also broadcast all prepared modules.
Use `Code.ensure_loaded?/1` as a guard before `:code.load_binary/3`.

```elixir
def init(opts) do
  modules_to_share = Keyword.get(opts, :share, [])
  Phoenix.PubSub.subscribe(@pubsub, @topic)
  :net_kernel.monitor_nodes(true)

  # Prepare bytecode for our modules
  prepared = Enum.reduce(modules_to_share, %{}, fn mod, acc ->
    case :code.get_object_code(mod) do
      {^mod, bin, file} -> Map.put(acc, mod, {bin, file})
      error -> acc
    end
  end)

  send(self(), :request_sync)  # ← pull from existing nodes
  {:ok, %{prepared: prepared}}
end

# Respond to pull requests — push our modules:
def handle_info({:request_modules, from_node}, state) do
  Enum.each(state.prepared, fn {mod, {bin, file}} ->
    Phoenix.PubSub.broadcast(@pubsub, @topic,
      {:got_module, Node.self(), mod, bin, file})
  end)
  {:noreply, state}
end

# On node join — push proactively:
def handle_info({:nodeup, node}, state) do
  Enum.each(state.prepared, fn {mod, {bin, file}} ->
    Phoenix.PubSub.broadcast(@pubsub, @topic,
      {:got_module, Node.self(), mod, bin, file})
  end)
  {:noreply, state}
end
```

**Key difference from ssr-robust-live-svg's Pattern 02:**
- Adds `:request_sync` pull mechanism — not just push on `:nodeup`
- Simpler: no separate `NodeListener` + `BehaviorModules` split
- Uses `Code.ensure_loaded?/1` guard before loading

**Source:** `private_service/lib/private_service/module_sharer.ex` (identical
pattern in all 3 services: `main_app`, `global_service`, `private_service`)

## Resulting Context

- ✓ Symmetric: every node both pushes and pulls
- ✓ Survives startup races via delayed `:request_sync`
- ✓ Deduplication via `Code.ensure_loaded?/1`
- ✗ All 3 services have identical copies of ModuleSharer — DRY violation
- ✗ No version tracking — can't detect stale modules

## Known Uses

- `independent_liveview_components_experiment`: All 3 services (this repo)
- Adapted from `ssr-robust-live-svg` Pattern 02 (Runtime Module Spread)

## Related Patterns

- Pattern 01 (Local Rendering): consumes modules spread by this pattern
- Pattern 04 (Graceful Degradation): `Code.ensure_loaded?/1` guard
