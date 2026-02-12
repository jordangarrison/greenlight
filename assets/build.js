const esbuild = require("esbuild")
const sveltePlugin = require("esbuild-svelte")
const importGlobPlugin = require("esbuild-plugin-import-glob").default
const sveltePreprocess = require("svelte-preprocess")

const path = require("path")

const args = process.argv.slice(2)
const watch = args.includes("--watch")
const deploy = args.includes("--deploy")

// Resolve node paths for Phoenix deps (phoenix-colocated, etc.)
const depsPath = path.resolve(__dirname, "../deps")
const buildPath = path.resolve(__dirname, "../_build/dev")

let clientConditions = ["svelte", "browser"]
let serverConditions = ["svelte"]

if (!deploy) {
    clientConditions.push("development")
    serverConditions.push("development")
}

let optsClient = {
    entryPoints: ["js/app.js"],
    bundle: true,
    minify: deploy,
    conditions: clientConditions,
    alias: {svelte: "svelte"},
    nodePaths: [depsPath, buildPath],
    external: ["node:*"],
    outdir: "../priv/static/assets/js",
    logLevel: "info",
    sourcemap: watch ? "inline" : false,
    tsconfig: "./tsconfig.json",
    plugins: [
        importGlobPlugin(),
        sveltePlugin({
            preprocess: sveltePreprocess(),
            compilerOptions: {dev: !deploy, css: "injected", generate: "client"},
        }),
    ],
}

let optsServer = {
    entryPoints: ["js/server.js"],
    platform: "node",
    bundle: true,
    minify: false,
    target: "node19.6.1",
    conditions: serverConditions,
    alias: {svelte: "svelte"},
    nodePaths: [depsPath, buildPath],
    outdir: "../priv/svelte",
    logLevel: "info",
    sourcemap: watch ? "inline" : false,
    tsconfig: "./tsconfig.json",
    plugins: [
        importGlobPlugin(),
        sveltePlugin({
            preprocess: sveltePreprocess(),
            compilerOptions: {dev: !deploy, css: "injected", generate: "server"},
        }),
    ],
}

if (watch) {
    esbuild
        .context(optsClient)
        .then(ctx => ctx.watch())
        .catch(_error => process.exit(1))

    esbuild
        .context(optsServer)
        .then(ctx => ctx.watch())
        .catch(_error => process.exit(1))
} else {
    esbuild.build(optsClient)
    esbuild.build(optsServer)
}
