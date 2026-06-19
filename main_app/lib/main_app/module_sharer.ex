defmodule ModuleSharer do
  use GenServer
  require Logger

  @pubsub MainApp.PubSub
  @topic "modules:sync"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    modules_to_share = Keyword.get(opts, :share, [])
    
    # Subscribe to sync topic
    Phoenix.PubSub.subscribe(@pubsub, @topic)
    
    # Monitor nodes in cluster
    :net_kernel.monitor_nodes(true)

    # Load and prepare object code for the modules we want to share
    prepared = Enum.reduce(modules_to_share, %{}, fn mod, acc ->
      case :code.get_object_code(mod) do
        {^mod, bin, file} ->
          Map.put(acc, mod, {bin, file})
        error ->
          Logger.warning("Could not get object code for #{inspect(mod)}: #{inspect(error)}")
          acc
      end
    end)

    # Periodically request modules from other nodes to sync on startup
    send(self(), :request_sync)

    {:ok, %{prepared: prepared}}
  end

  def handle_info(:request_sync, state) do
    Logger.debug("Requesting modules from other nodes...")
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:request_modules, Node.self()})
    {:noreply, state}
  end

  def handle_info({:request_modules, from_node}, state) do
    if from_node != Node.self() do
      Logger.debug("Node #{inspect(from_node)} requested modules. Spreading our prepared modules.")
      Enum.each(state.prepared, fn {mod, {bin, file}} ->
        Phoenix.PubSub.broadcast(@pubsub, @topic, {:got_module, Node.self(), mod, bin, file})
      end)
    end
    {:noreply, state}
  end

  def handle_info({:got_module, from_node, mod, bin, file}, state) do
    if from_node != Node.self() do
      case Code.ensure_loaded(mod) do
        {:module, _} ->
          # Already loaded, check if we need to log it or skip
          :ok
        _ ->
          Logger.info("Loading dynamic module #{inspect(mod)} from #{inspect(from_node)}...")
          case :code.load_binary(mod, file, bin) do
            {:module, ^mod} ->
              Logger.info("Successfully loaded dynamic module #{inspect(mod)}")
              # Notify parent LiveView (or any local processes) that a new module is available
              Phoenix.PubSub.local_broadcast(@pubsub, "modules:new:local", {:new_module_local, mod})
            {:error, reason} ->
              Logger.error("Failed to load dynamic module #{inspect(mod)}: #{inspect(reason)}")
          end
      end
    end
    {:noreply, state}
  end

  def handle_info({:nodeup, node}, state) do
    Logger.info("Node joined cluster: #{inspect(node)}. Spreading our prepared modules.")
    Enum.each(state.prepared, fn {mod, {bin, file}} ->
      Phoenix.PubSub.broadcast(@pubsub, @topic, {:got_module, Node.self(), mod, bin, file})
    end)
    {:noreply, state}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.info("Node left cluster: #{inspect(node)}")
    {:noreply, state}
  end
end
