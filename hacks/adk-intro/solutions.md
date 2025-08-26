# Introduction to Agents with ADK

## Introduction

Welcome to the coach's guide for Introduction to Agents with ADK gHack. Here you will find links to specific guidance for coaches for each of the challenges.

> [!NOTE]  
> If you are a gHacks participant, this is the answer guide. Don't cheat yourself by looking at this guide during the hack!

> [!IMPORTANT]  
> As of June 2024 *Cloud Source Repositories* is [end of sale](https://cloud.google.com/source-repositories/docs/release-notes#June_17_2024). However, any organization that has created at least one CSR repository in the past, will still have access to existing repositories and will be able to create new ones. If you're running this in a Qwiklabs environment you're good to go, but if you're running this in **your** own environment, please verify that you have access to *Cloud Source Repositories* in your organization.

## Coach's Guides

## Challenges

- Challenge 1: First Contact  
- Challenge 2: The Hero Toolkit  
- Challenge 3: Agent's Logbook  
- Challenge 4: Teamwork  
- Challenge 5: MCP as the Matchmaker  
- Challenge 6: A2A: Signal Received
- Challenge 7: Acting Agent

## Challenge 1: First Contact

### Notes & Guidance

The first step is to clone the repository that has been created for the team.

> [!IMPORTANT]  
> We're using Cloud Source Repositories for this hack, which still uses `master` as the default branch. The easiest option is to stick to that.

```shell
git clone https://source.developers.google.com/p/$GOOGLE_CLOUD_PROJECT/r/ghacks-adk-intro
```

Once the repository is cloned, although it's not a hard requirement, the best practice is to start with a virtual environment. There are multiple tools to create virtual environments and install packages but we'll stick to the defaults.

```shell
cd ghacks-adk-intro
python3 -m venv venv
source venv/bin/activate
```

Now we can install the required libraries.

```shell
pip install -r requirements.txt
```

One final step before we can start running the `adk web` command is to set some environment variables.

```shell
REGION=us-central1
cat > .env <<EOF
GOOGLE_GENAI_USE_VERTEXAI=TRUE
GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT
GOOGLE_CLOUD_LOCATION=$REGION
EOF
source .env
```

Now we can run the `adk web` command and preview it by clicking the web preview icon in the Cloud Shell menu and selecting Preview and Change Port to 8000.

## Challenge 2: The Hero Toolkit

### Notes & Guidance

The new driver should follow the same steps to clone the repository and set up their environment.

Then edit the `heroes/agent.py` to update the prompt and configure the tool.

```python
hero_finder_agent = Agent(
    name="hero_finder_agent",
    model=settings.GEMINI_MODEL,
    instruction="""
    Return super heroes to respond to the threat.
    Use the provided `get_available_heroes` tool to find the list of available heroes.
    """,
    tools=[tools.get_available_heroes]
)
```

Make sure that the changes are pushed to the repository so the next driver can pick up the changes.

## Challenge 3: Agent's Logbook

### Notes & Guidance

Again the new driver should follow the same steps for the first challenge to clone the repository (or pull the latest changes if they have already cloned it) and set up their environment (if they haven't done that already).

Then edit the `heroes/agent.py` to update the prompt and configure the `output_key`. It's also possible to introduce another tool that stores things explicitly in the session state, which is fine too.

```python
hero_finder_agent = Agent(
    name="hero_finder_agent",
    model=settings.GEMINI_MODEL,
    instruction="""
    Return super heroes to respond to the threat.
    Use the provided `get_available_heroes` tool to find the list of available heroes.
    Return only a comma separated list of available heroes, or nothing if there are no available heroes.
    """,
    tools=[tools.get_available_heroes],
    output_key="available_heroes"
)

root_agent = hero_finder_agent
```

Make sure that the changes are pushed to the repository so the next driver can pick up the changes.

## Challenge 4: Teamwork

### Notes & Guidance

Again the new driver should follow the same steps for the first challenge to clone the repository (or pull the latest changes if they have already cloned it) and set up their environment (if they haven't done that already).

```python
# keep other imports

from google.adk.agents import SequentialAgent

# keep hero_finder_agent as is

threat_analyzer_agent = Agent(
    name="threat_analyzer_agent",
    model=settings.GEMINI_MODEL,
    instruction="""
    Based on the alert message classify the threat into one of `MYSTICAL`, `TECHNOLOGICAL`, or `CRIMINAL`.
    """,
    output_key="threat_type"
)

dispatcher_agent = SequentialAgent(
    name="dispatcher_agent",
    sub_agents=[hero_finder_agent, threat_analyzer_agent]
)

root_agent = dispatcher_agent
```

Make sure that the changes are pushed to the repository so the next driver can pick up the changes.

## Challenge 5: MCP as the Matchmaker

### Notes & Guidance

Again the new driver should follow the same steps for the first challenge to clone the repository (or pull the latest changes if they have already cloned it) and set up their environment (if they haven't done that already).

First step is to run the Cloud Run proxy to simplify things.

```shell
gcloud run services proxy --region $REGION --port=8888 mcp-server
```

The following snippet indicates what needs to be changed.

```python
# keep other imports
from google.adk.tools.mcp_tool import MCPToolset
from google.adk.tools.mcp_tool import StreamableHTTPConnectionParams

# keep hero_finder_agent and threat_analyzer_agent as is

mcp_tool_set = MCPToolset(
    connection_params=StreamableHTTPConnectionParams(
        url="http://localhost:8888/mcp"
    )
)

hero_matcher_agent = Agent(
    name="hero_matcher_agent",
    model=settings.GEMINI_MODEL,
    instruction="""
    Using the {available_heroes} and {threat_type} find the most appropriate hero with the `match_hero` tool.
    Return only the name of the chosen hero.
    """,
    tools=[mcp_tool_set],
    output_key="chosen_hero"
)

dispatcher_agent = SequentialAgent(
    name="dispatcher_agent",
    sub_agents=[hero_finder_agent, threat_analyzer_agent, hero_matcher_agent]
)
```

Make sure that the changes are pushed to the repository so the next driver can pick up the changes.

## Challenge 6: A2A: Signal Received

### Notes & Guidance

Again the new driver should follow the same steps for the first challenge to clone the repository (or pull the latest changes if they have already cloned it) and set up their environment (if they haven't done that already).

First step is to run the Cloud Run proxy to simplify things.

```shell
gcloud run services proxy --region $REGION --port=8080 a2a-server
```

> [!IMPORTANT]  
> Currently when an A2A Agent is accessed through the Cloud Run proxy, the proxy port must match the port that the container is running on (which is port `8080` by default). Note that this only applies to the A2A server, the MCP server can be proxied through any port.

The following snippet indicates what needs to be changed.

```python
# keep other imports
from google.adk.agents.remote_a2a_agent import AGENT_CARD_WELL_KNOWN_PATH
from google.adk.agents.remote_a2a_agent import RemoteA2aAgent

# keep hero_finder_agent, threat_analyzer_agent, and hero_matcher_agent as is

signal_hero_agent = RemoteA2aAgent(
    name="signal_hero_agent",
    description="Agent that handles signaling the chosen hero",
    agent_card=(
        f"http://localhost:8080/a2a/signal_hero_agent{AGENT_CARD_WELL_KNOWN_PATH}"
    )
)

dispatcher_agent = SequentialAgent(
    name="dispatcher_agent",
    sub_agents=[hero_finder_agent, threat_analyzer_agent, hero_matcher_agent, signal_hero_agent]
)
```

Make sure that the changes are pushed to the repository so the next driver can pick up the changes.

## Challenge 7: Acting Agent

### Notes & Guidance

Again the new driver should follow the same steps for the first challenge to clone the repository (or pull the latest changes if they have already cloned it) and set up their environment (if they haven't done that already).

This should be pretty much trivial, it's all about adding another agent to the sequence that updates the availability database.

```python
update_availability_agent = Agent(
    name="update_availability_agent",
    model=settings.GEMINI_MODEL,
    instruction="""
    Update the availability database to indicate that the {chosen_hero} is not available anymore using the `update_hero_availability` tool.
    """,
    tools=[tools.update_hero_availability]
)

dispatcher_agent = SequentialAgent(
    name="dispatcher_agent",
    sub_agents=[
        hero_finder_agent, 
        threat_analyzer_agent, 
        hero_matcher_agent, 
        signal_hero_agent,
        update_availability_agent
    ]
)
```
