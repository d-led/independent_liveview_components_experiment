# Independent Phoenix LiveView Micro-UIs Experiment

## Motivation

- allow multiple teams to deploy parts of a LiveView independently with maximum simplicity
- there's no settled optimum yet, ideas are welcome

## Current Architecture

- 3 independent nodes connected in a cluster
- [main_app](./main_app/) acts as the front-end, serving the [main page](main_app/lib/main_app_web/live/main_live.ex)
- [global_service](./global_service/) and [private_service](./private_service/) [push rendered partial LiveViews](private_service/lib/private_service/private_click_aggregator_service.ex) into Pub/Sub, to which the `main_app` is subscribed, rendering them as they are, within the main view.
- the services also expose their own LiveViews for e.g. their "admin" purposes

![3 mini UIs](./docs/img/3-mini-uis.gif)

### Architecture at a Glance

#### 1. Cluster Topology & Network (High Level)
Shows how the 3 independent service nodes form a cluster and communicate using a shared clustered PubSub adapter.

```mermaid
flowchart TD
    subgraph Network ["Erlang Node Cluster (127.0.0.1)"]
        direction LR
        MainNode["main_app<br>(Port 4000)"]
        GlobalNode["global_service<br>(Port 4001)"]
        PrivateNode["private_service<br>(Port 4002)"]
        
        MainNode <--> |libcluster Gossip| GlobalNode
        MainNode <--> |libcluster Gossip| PrivateNode
        GlobalNode <--> |libcluster Gossip| PrivateNode
    end

    subgraph PubSub ["Shared Infrastructure"]
        PubSubServer["MainApp.PubSub (PG2/PG)"]
    end

    MainNode -.-> PubSubServer
    GlobalNode -.-> PubSubServer
    PrivateNode -.-> PubSubServer
```

#### 2. Click Interaction & HTML UI Update Flow
Shows the path of a click event and how micro-UI partial views are rendered and updated back to the user.

```mermaid
flowchart TD
    User([User Browser]) -->|Clicks button| MainLive["MainAppWeb.MainLive"]
    
    %% Click Event Broadcast
    MainLive -->|1. Broadcast event: 'click'| GlobalTopic["Topic: global_topic"]
    
    %% Aggregation
    GlobalTopic --> GlobalAgg["GlobalClickAggregatorService"]
    GlobalTopic --> PrivateAgg["PrivateClickAggregatorService"]
    
    %% HTML Rendering Broadcasts
    GlobalAgg -->|2. Broadcast view: :global| GlobalRender["Topic: global_rendering_topic"]
    PrivateAgg -->|3. Broadcast view: :private| PrivateRender["Topic: private_clicks::session_id"]
    
    %% LiveView rendering
    GlobalRender -->|Renders component| MainLive
    PrivateRender -->|Renders component| MainLive
    MainLive -->|Updates UI| User
```

#### 3. Session Presence & Status Tracking

- `MainLive.mount` calls `Presence.track/4` with the session ID into `"presence:lobby"`.
- Phoenix Presence replicates state across nodes using an internal CRDT — no extra infra needed.
- The Sessions Service subscribes to `"presence:lobby"` and renders a green dot for online sessions, gray for offline.
- Caveat: presence diffs don't always reach services reliably in a gossip-based cluster; a `"hi"` message on the `arrivals` topic serves as a workaround on mount.

#### 4. Team Independence via Module Spreading

Each service team deploys their own compiled view module independently.
The module only travels **once** at cluster join time; only small data payloads cross PubSub per event.

```mermaid
flowchart TD
    subgraph private_service["private_service node"]
        PSModuleSharer["ModuleSharer\n(GenServer)"]
        PSViews["PrivateServiceWeb.PrivateClickViews\n(compiled BEAM module)"]
        PSAgg["PrivateClickAggregatorService"]
    end

    subgraph main_app["main_app node"]
        MAModuleSharer["ModuleSharer\n(receives modules)"]
        MALive["MainAppWeb.MainLive"]
    end

    PSModuleSharer -->|":nodeup → :code.get_object_code/1\n→ broadcast on 'modules:sync'"| MAModuleSharer
    MAModuleSharer -->|":code.load_binary/3\n→ local_broadcast 'modules:new:local'"| MALive

    PSAgg -->|"PubSub broadcast\n{view: :private, count: N}\non 'private_clicks:session_id'"| MALive

    MALive -->|"apply(PrivateServiceWeb.PrivateClickViews, :render, [assigns])\n← module already loaded locally"| MALive
```

**What travels and when:**

| What | When | Size |
|------|------|------|
| BEAM module bytecode | Once, on cluster join | ~KB, once |
| Event data (`count`, `session_id`) | Per user interaction | Tiny |
| HTML | Never — rendering is local on `main_app` | — |

### Challenges

- current docker compose / libcluster config creates a sporadically disconnected cluster
- presence diffs don't always reach services reliably across gossip-based cluster nodes
  - workaround: a custom `"hi"` message is published to `arrivals` on LiveView mount, triggering a fresh render from services

### Pending Ideas

- 3 LiveView sockets
  - potentially served via the same reverse proxy under different paths
- other approaches, unifying the LiveView socket?
- when a service goes down / hasn't sent updates in a while, show a `currently unavailable` message in the main view
  - custom monitor?
  - custom scheduled messages to `self()` in main LiveView?

### Failed Approaches

- trying to render the diffs only:
  - unfortunately, this failed with the diff (?) functions not being present on the `main_app`


## Start with process-compose

- install [process-compose](https://f1bonacc1.github.io/process-compose/installation/)
- `process-compose``
- &rarr; http://localhost:4000
  - http://localhost:4001
  - http://localhost:4002

## Start with docker compose

- `docker compose up` (with other options depending on the needs)
- &rarr; http://localhost:4001
  - http://localhost:4001/services/global
  - http://localhost:4001/services/private