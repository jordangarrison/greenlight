# Changelog

## [0.3.0](https://github.com/jordangarrison/greenlight/compare/v0.2.0...v0.3.0) (2026-03-07)


### Features

* add paginated full views for user PRs and commits ([#13](https://github.com/jordangarrison/greenlight/issues/13)) ([2377eca](https://github.com/jordangarrison/greenlight/commit/2377eca55e689ee25076f4c5e6b3c968b55a4c51))


### Bug Fixes

* **ci:** move docker publish into release-please workflow ([#15](https://github.com/jordangarrison/greenlight/issues/15)) ([5634121](https://github.com/jordangarrison/greenlight/commit/563412138ee9d0086224ae4dbd4e457302084ca2))

## [0.2.0](https://github.com/jordangarrison/greenlight/compare/v0.1.0...v0.2.0) (2026-03-04)


### Features

* add Ash declarative data layer for GitHub resources ([#10](https://github.com/jordangarrison/greenlight/issues/10)) ([8b9ae73](https://github.com/jordangarrison/greenlight/commit/8b9ae734b9db82111d9fbe24da5600510717e1fa))
* add container support via Nix-built OCI image ([22ce9fb](https://github.com/jordangarrison/greenlight/commit/22ce9fb89f43b1454845c20dbeca9a18b54c6461))
* add docker image build verification to precommit and dashboard screenshot ([fac3ead](https://github.com/jordangarrison/greenlight/commit/fac3ead474ea231fa1ed415686faa54e3f0820eb))
* add expand indicator to WorkflowNode and click-to-GitHub on JobNode ([76e8444](https://github.com/jordangarrison/greenlight/commit/76e84449266b5e141f7c1efe75db73c5896908a2))
* add expandable workflow jobs to DagViewer ([cb6cb82](https://github.com/jordangarrison/greenlight/commit/cb6cb82a1d6bcb79c73dc42b612fe8ce70e1d824))
* add get_authenticated_user/0 to GitHub client ([77d3873](https://github.com/jordangarrison/greenlight/commit/77d38738ec7056fd58da7324267479103285d439))
* add GitHub Actions data model structs with API parsing ([acae6c0](https://github.com/jordangarrison/greenlight/commit/acae6c0f968090456e454a3edeb5ade9cfdb5b44))
* add GitHub API client with Req for workflow runs, jobs, repos, PRs, branches, releases ([89d3920](https://github.com/jordangarrison/greenlight/commit/89d392054431a210c07d72c14bdeca043a66d6f3))
* add GitHub links to pipeline view ([88861f7](https://github.com/jordangarrison/greenlight/commit/88861f7970579ec4dd0387a9ce9cfac68e0ac979))
* add GitHub links to pipeline view ([b0c6685](https://github.com/jordangarrison/greenlight/commit/b0c6685f3ba7e2f9ba600b567dcef7dd4faf8d1b))
* add greenlight config, poller supervisor to application tree ([c4ec936](https://github.com/jordangarrison/greenlight/commit/c4ec936d1922c9bbf97ce92b260a003977491232))
* add HTTP request telemetry logger and environment metadata ([346da60](https://github.com/jordangarrison/greenlight/commit/346da60e633460100a932fba6f83e239e7579579))
* add LiveSvelte, libgraph, and Svelte Flow dependencies ([293d7d4](https://github.com/jordangarrison/greenlight/commit/293d7d4f203a2f9ffdab0fcf6e0246c89550458c))
* add LiveViews for pipeline DAG, dashboard, and repo browser ([b92f519](https://github.com/jordangarrison/greenlight/commit/b92f51948203ebeedf2a4e9224d031a5bd707c58))
* add logger_json and configure structured JSON logging ([d660d1c](https://github.com/jordangarrison/greenlight/commit/d660d1c880c691f401ccebada051c5bf6e030a0b))
* add Nix package and NixOS service module ([f3c6a3d](https://github.com/jordangarrison/greenlight/commit/f3c6a3d4e55e2a90e85d590f045c8c2beab5b934))
* add nix/docker.nix for OCI image build ([cab7c67](https://github.com/jordangarrison/greenlight/commit/cab7c67042a2fb5325a80eff8cba4145af2a09fa))
* add poller GenServer with PubSub broadcasting and DynamicSupervisor lifecycle ([233cb54](https://github.com/jordangarrison/greenlight/commit/233cb54fcae867ec421bd55197f3c6920652552b))
* add relative time helper ([4600fe2](https://github.com/jordangarrison/greenlight/commit/4600fe27f252cdb985de9b4c99d5961dca55ae50))
* add ReqLogger Req plugin for GitHub API call logging ([0a62ea8](https://github.com/jordangarrison/greenlight/commit/0a62ea85537c263202157449a822dd331f1b558d))
* add search_user_commits/1 to GitHub client ([4157f5f](https://github.com/jordangarrison/greenlight/commit/4157f5f2f2f4126ea4bdeccb2420188b0782af9e))
* add search_user_prs/1 to GitHub client ([c10ca3c](https://github.com/jordangarrison/greenlight/commit/c10ca3c36121bdf3fff3184607c996fed63d1fce))
* add serialize_workflow_runs for client-side job expansion ([9fc0236](https://github.com/jordangarrison/greenlight/commit/9fc0236e69a8abec14ebe60fd17739b6f541be87))
* add structured wide event logging ([01c3205](https://github.com/jordangarrison/greenlight/commit/01c3205308c49f18799b9aaa119f2fd65b8ab7e2))
* add Svelte Flow DAG components with dagre layout and Svelte 5 runes ([04d2115](https://github.com/jordangarrison/greenlight/commit/04d2115946f318a0795c0b47f7f6a0f5fae2ec77))
* add user insights dashboard section ([4f233cc](https://github.com/jordangarrison/greenlight/commit/4f233cc6983e504f05c587eb1309de7add5ddf75))
* add user insights section to dashboard template ([824853a](https://github.com/jordangarrison/greenlight/commit/824853a49aa5572691f8f47af916cc549cd0f311))
* add wide event logging to LiveView mount and pipeline updates ([1ad1740](https://github.com/jordangarrison/greenlight/commit/1ad174005a8e4a2ea7e98de4c56870a2777d8b93))
* add wide event logging to Poller GenServer poll cycles ([f445253](https://github.com/jordangarrison/greenlight/commit/f4452530cae0250a490d428d1f8d3825aa54d29d))
* add WideEvent core module for structured wide event logging ([93c291a](https://github.com/jordangarrison/greenlight/commit/93c291af0be2d91349c26535ea94481caec63f96))
* add workflow graph builder to transform API data into Svelte Flow nodes/edges ([e64b5f0](https://github.com/jordangarrison/greenlight/commit/e64b5f08a618cbc3759338241d1de78bccb6f094))
* cache user insights with background GenServer and fix dashboard links ([cc6ac5b](https://github.com/jordangarrison/greenlight/commit/cc6ac5bae6c6489a100c88255ecc0469553d6f10))
* include workflow_runs in poller broadcast ([2737939](https://github.com/jordangarrison/greenlight/commit/2737939297d5dc99697a9224a0008bacca1ed292))
* integrate ReqLogger plugin into GitHub API client ([f602d21](https://github.com/jordangarrison/greenlight/commit/f602d21d16c170c655fd65a01e7da2363aa0595e))
* load authenticated user and activity in dashboard mount ([e59bc03](https://github.com/jordangarrison/greenlight/commit/e59bc03e61b5a3e82ffcb1060b348be99b2e1aa1))
* redesign app shell with neubrutalist navbar ([e278b52](https://github.com/jordangarrison/greenlight/commit/e278b52e32cef175a506eeb2c708d11417d28a30))
* redesign DAG viewer with mindmap tree layout ([b7a62f1](https://github.com/jordangarrison/greenlight/commit/b7a62f1af71c384501dec12c69d9541625e6daf9))
* redesign dashboard with neubrutalist cards and layout ([6daff94](https://github.com/jordangarrison/greenlight/commit/6daff949a95819541f8354437473f0edcaa72ab7))
* redesign pipeline view with neubrutalist framing ([1f6f06d](https://github.com/jordangarrison/greenlight/commit/1f6f06d9ddd3fd8b84dac051356518eb6ddd0d64))
* redesign repo browser with neubrutalist tabs and cards ([42db5bd](https://github.com/jordangarrison/greenlight/commit/42db5bd62f40c009a166c33f726be90f82135f1f))
* resolve job needs dependencies from workflow YAML ([7a03bba](https://github.com/jordangarrison/greenlight/commit/7a03bba5f2090cdd75839e87e94e835b165eee32))
* restyle core components with neubrutalist design ([c3d0239](https://github.com/jordangarrison/greenlight/commit/c3d0239a94b7bab593bdb165d19ff4fc9541b1f0))
* restyle DAG nodes with neubrutalist card design ([df159b3](https://github.com/jordangarrison/greenlight/commit/df159b3710fc7f1252a813608bce6abcb97fde0b))
* restyle DagViewer with dark neubrutalist theme ([b25ddb5](https://github.com/jordangarrison/greenlight/commit/b25ddb5bd19780ed4c28ba56be054e7b1fefec1c))
* restyle StatusBadge and ProgressBar with neubrutalist design ([a4bc8e3](https://github.com/jordangarrison/greenlight/commit/a4bc8e3016863c02c83b62359c0076c8824af737))
* simplify PipelineLive to pass workflow_runs for inline expansion ([82df446](https://github.com/jordangarrison/greenlight/commit/82df446397036c475608c6365f0b88815a63dfaa))
* simplify root layout, remove theme toggle ([90a97af](https://github.com/jordangarrison/greenlight/commit/90a97af19a362000fd7ac7e44bed8ff5dcac49a8))
* strip daisyUI and add neubrutalist design system CSS ([cfa8b4c](https://github.com/jordangarrison/greenlight/commit/cfa8b4c5b2b956700ea11383dad54da5799fea41))
* wire dockerImage output into flake.nix ([1e18fb8](https://github.com/jordangarrison/greenlight/commit/1e18fb87a431350a3a727e4eac8835890b773ac9))


### Bug Fixes

* add glowing green circle SVG favicon ([de3ed30](https://github.com/jordangarrison/greenlight/commit/de3ed30fa215daa5af93e0165ce3d23b7f9af0fd))
* add OCI labels to container image for GHCR repo linking ([cadfa9c](https://github.com/jordangarrison/greenlight/commit/cadfa9c9185fe9ff16ce9eb99f136e75e510b5a8))
* correct onnodeclick callback signature and CSS edge overrides ([14c9e84](https://github.com/jordangarrison/greenlight/commit/14c9e8440c219686bc1710c0ca3bd85e7c7a2493))
* format dashboard live test ([6e152ea](https://github.com/jordangarrison/greenlight/commit/6e152ea827ee97248447047c62bf13f3099b9a68))
* include nodejs in container for live_svelte SSR ([b61cce0](https://github.com/jordangarrison/greenlight/commit/b61cce0f8e42c5af1a361d463e8e6e1eb25fd55c))
* preserve DAG viewport and UI state across poll cycles ([#9](https://github.com/jordangarrison/greenlight/issues/9)) ([e135858](https://github.com/jordangarrison/greenlight/commit/e135858bfdbedca6c96980b2021d9163eea249ca))
* resolve LiveView WebSocket origin check and favicon 404 ([22228ef](https://github.com/jordangarrison/greenlight/commit/22228efc4392ed89f0115bba3ff448d731066ae2))
* run container as non-root greenlight user ([65d614a](https://github.com/jordangarrison/greenlight/commit/65d614ac1224bcbdf58ee72e9a6d7d6a367780e0))
* set container defaults for locale, scheme, and url port ([71cd42a](https://github.com/jordangarrison/greenlight/commit/71cd42a07559b8aaf7c20b0ca1637873fddd63a8))
* set RELEASE_COOKIE for container startup ([82ffe7d](https://github.com/jordangarrison/greenlight/commit/82ffe7d285a420dc6b6a97a32987793112c161c0))
* update stale mixFodDeps hash and add nix build CI job ([f16908c](https://github.com/jordangarrison/greenlight/commit/f16908c2aee2b5264125564b890faf07b595af92))
* update stale Nix deps hash and add build CI job ([1cc4144](https://github.com/jordangarrison/greenlight/commit/1cc4144fbd71ab37d169b53b8a9115539c7ea592))
* update stale npmDepsHash for @xyflow/svelte 1.5.1 ([9a7389a](https://github.com/jordangarrison/greenlight/commit/9a7389a240bc73680da0ed8ba351550eb2198c35))
* use global logger metadata instead of process-local ([2bd481b](https://github.com/jordangarrison/greenlight/commit/2bd481b64acc9c3bbd39a53fb561577111127bdb))


### Documentation

* add container build and run instructions to README ([4b9d926](https://github.com/jordangarrison/greenlight/commit/4b9d9260507076cb376e595e781ccff9fc39fda5))
* add GitHub Actions DAG viewer design document ([c976cdb](https://github.com/jordangarrison/greenlight/commit/c976cdb8403305fd6e766989e10453b3a67010fa))
* add implementation plan for GitHub Actions DAG viewer ([8de699d](https://github.com/jordangarrison/greenlight/commit/8de699dc3bfdebc5359c35a290814991d067c01d))
* add structured logging section to CLAUDE.md ([a31f523](https://github.com/jordangarrison/greenlight/commit/a31f5232990fba2754ace952589d2edec62e489a))
* add user insights dashboard design ([c6ea7b3](https://github.com/jordangarrison/greenlight/commit/c6ea7b3d28222ff326659eafb385a86f9b14cd28))
* add user insights implementation plan ([e759b7d](https://github.com/jordangarrison/greenlight/commit/e759b7d80b2d040a29494463928889455e33462a))
* add wide event logging design ([4b89941](https://github.com/jordangarrison/greenlight/commit/4b899417c414be5e4ab7687a7f7f85d8425c78b7))
* add wide event logging implementation plan ([6be94dc](https://github.com/jordangarrison/greenlight/commit/6be94dc30e5ddeebe81fe68493bd807ded1e76f9))


### Styles

* format config.exs logger_json config line ([77f583b](https://github.com/jordangarrison/greenlight/commit/77f583bb7497042c10733846a6b506663954c148))


### Miscellaneous Chores

* add .grove to gitignore and container support design doc ([3e939f0](https://github.com/jordangarrison/greenlight/commit/3e939f0447056ddeba8b453c7be31b95f9d4d585))
* add grove to gitignore and pr review findings doc ([b00b813](https://github.com/jordangarrison/greenlight/commit/b00b81362502b06bd3eb5c624cec63b4f4d8ff5f))
* bump @xyflow/svelte to 1.5.1 ([f4b3aef](https://github.com/jordangarrison/greenlight/commit/f4b3aef01cbdfb83d4933a9d7ed50db931cbf64b))
* format and cleanup after neubrutalist redesign ([f21b94c](https://github.com/jordangarrison/greenlight/commit/f21b94c660d337ede00d98ac33f884de55972b16))
* prepare repo for public release ([2368dd4](https://github.com/jordangarrison/greenlight/commit/2368dd42427ec137bde8ebbd6cc80a8987593210))
* use nodejs-slim for smaller container image ([74d7b5b](https://github.com/jordangarrison/greenlight/commit/74d7b5bc1d49fd3e9b7d819dbdb579de5520ba0d))


### Tests

* add dashboard live test for user insights section ([e247cca](https://github.com/jordangarrison/greenlight/commit/e247ccaade388ba3e73a2e7acae7a847ecf7f9ce))


### Continuous Integration

* add release-please and Docker image publishing pipeline ([#11](https://github.com/jordangarrison/greenlight/issues/11)) ([90c37c5](https://github.com/jordangarrison/greenlight/commit/90c37c54a20c587c3da2278071b0f0f3914779de))
* add test and container deploy workflow ([f85863a](https://github.com/jordangarrison/greenlight/commit/f85863a4b033a830c2a73c3ae2430eee648933b7))
* cache mix dependencies between runs ([e96ed95](https://github.com/jordangarrison/greenlight/commit/e96ed954d8d3684e4cbb6fc2a860b5415b1a8dba))
* pin actions to release tags and apply review findings ([3f882d1](https://github.com/jordangarrison/greenlight/commit/3f882d1c0358a5b48ccf06d0f96713513e169b3d))
