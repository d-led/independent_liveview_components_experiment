defmodule MainApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MainAppWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:main_app, :dns_cluster_query) || :ignore},
      {Cluster.Supervisor, [topologies() |> IO.inspect(label: "chosen cluster config")]},
      {Phoenix.PubSub, name: MainApp.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: MainApp.Finch},
      # Start a worker by calling: MainApp.Worker.start_link(arg)
      # {MainApp.Worker, arg},
      # Start to serve requests, typically the last entry
      MainAppWeb.Endpoint,
      MainAppWeb.Presence,
      {MainApp.GlobalClickAggregatorService, []},
      {MainApp.PrivateClickAggregatorService, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MainApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MainAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp topologies() do
    case System.get_env("ERLANG_SEED_NODES", "")
         |> String.split(",") |> Enum.reject(&String.trim(&1) == "")
         |> Enum.map(&String.to_atom/1) do
      [] ->
        [
          default: [
            strategy: Cluster.Strategy.Gossip
          ]
        ]

      seed_nodes ->
        [
          default: [
            strategy: Cluster.Strategy.Epmd,
            config: [hosts: seed_nodes]
          ]
        ]
    end
  end
end
