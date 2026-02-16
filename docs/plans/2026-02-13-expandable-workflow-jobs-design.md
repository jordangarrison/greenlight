# Expandable Workflow Jobs in DAG Viewer

## Overview

Extend the PipelineLive DAG viewer so that workflow nodes can be expanded inline to reveal their child job nodes, eliminating the need for a separate "jobs" view mode.

## Interaction Model

- **Clicking a workflow node body** toggles expand/collapse for that workflow
- **Multiple workflows** can be expanded simultaneously
- **Clicking a job node body** opens the job's GitHub Actions URL in a new tab
- **Existing small GitHub link button** on workflow nodes remains for navigating to the workflow run on GitHub

## Layout

- Jobs branch to the **right** of their parent workflow, continuing the existing left-to-right (LR) Dagre layout
- A connector edge links the workflow node to each **root job** (jobs with empty `needs`)
- Job-to-job edges follow existing `needs` dependencies
- Dagre re-layouts the full graph on expand/collapse

## Visual Hierarchy

- **Workflow-to-job connector edges**: dashed style with parent workflow's status color
- **Job-to-job dependency edges**: solid, slightly thinner than workflow-to-workflow edges
- **Job nodes**: existing neobrutalist style with slightly smaller shadow (2px vs 3px)
- **Expanded workflow indicator**: visual cue on the workflow node (chevron or border change)

## Implementation

### Elixir (server-side)

**PipelineLive** (`pipeline_live.ex`):
- Pass `workflow_runs` data (with embedded jobs) as a new prop to the DagViewer Svelte component
- No view mode switching needed — single unified view
- No changes to WorkflowGraph, Poller, or Client modules

### Svelte (client-side)

**DagViewer.svelte**:
- New `workflowRuns` prop containing full workflow run objects with jobs
- Local `expandedWorkflows` Set state tracking which workflow IDs are expanded
- `buildJobNodes(workflowRun)` function: creates job nodes and edges client-side from the workflow's job data
- Job node IDs namespaced as `job-{runId}-{jobId}` to avoid collisions
- Reactive derivation: base workflow nodes + expanded job nodes merged, then Dagre layout applied
- Handle `toggleExpand` custom event from WorkflowNode

**WorkflowNode.svelte**:
- Node body click dispatches `toggleExpand` event with run ID (instead of view switching)
- Visual indicator for expanded/collapsed state
- Existing GitHub link button unchanged

**JobNode.svelte**:
- Add click handler on node body to open `html_url` in new tab (window.open)

### No new files needed

- No new routes
- No new API calls
- No new components
- All job data already available via the poller
