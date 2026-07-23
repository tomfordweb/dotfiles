import { existsSync, readFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"
import { spawnSync } from "node:child_process"
import type { Plugin } from "@opencode-ai/plugin"

type ClaudeMcpServer = {
  type?: string
  command?: string
  args?: string[]
  env?: Record<string, string>
  url?: string
  headers?: Record<string, string>
}

type ClaudeMcpConfig = {
  mcpServers?: Record<string, ClaudeMcpServer>
}

const instructionBasenames = ["AGENTS.md", "CLAUDE.md"]
const claudeAngularGuardPath = join(homedir(), ".claude", "hooks", "angular-rxjs-leak-guard.js")

function appendUnique(list: string[] | undefined, values: string[]) {
  const result = [...(list ?? [])]
  for (const value of values) {
    if (!result.includes(value)) result.push(value)
  }
  return result
}

function projectInstructionPaths(directory: string) {
  return instructionBasenames
    .map((name) => join(directory, name))
    .filter((path) => existsSync(path))
}

function loadClaudeMcp(directory: string) {
  const file = join(directory, ".mcp.json")
  if (!existsSync(file)) return undefined

  let parsed: ClaudeMcpConfig
  try {
    parsed = JSON.parse(readFileSync(file, "utf8")) as ClaudeMcpConfig
  } catch {
    return undefined
  }

  const entries = Object.entries(parsed.mcpServers ?? {})
  if (!entries.length) return undefined

  const mapped = entries.flatMap(([name, server]) => {
    if (server.type === "stdio" && server.command) {
      return [[name, {
        type: "local",
        command: [server.command, ...(server.args ?? [])],
        environment: server.env ?? {},
      }]]
    }

    if ((server.type === "sse" || server.type === "http") && server.url) {
      return [[name, {
        type: "remote",
        url: server.url,
        headers: server.headers ?? {},
      }]]
    }

    return []
  })

  return mapped.length ? Object.fromEntries(mapped) : undefined
}

function getFilePath(input: any, output: any) {
  return (
    output?.args?.filePath ??
    output?.args?.file_path ??
    input?.args?.filePath ??
    input?.args?.file_path ??
    input?.filePath ??
    input?.file_path ??
    ""
  )
}

function warnOnAngularSubscribeLeak(filePath: string) {
  if (!filePath || !/\.(ts|tsx)$/.test(filePath) || !existsSync(filePath)) return

  if (existsSync(claudeAngularGuardPath)) {
    const result = spawnSync("node", [claudeAngularGuardPath], {
      input: JSON.stringify({ tool_input: { file_path: filePath } }),
      encoding: "utf8",
    })

    if (result.status === 2) {
      throw new Error(result.stderr.trim() || `[angular-rxjs-leak-guard] ${filePath}`)
    }

    if (result.status === 0) return
  }

  let source = ""
  try {
    source = readFileSync(filePath, "utf8")
  } catch {
    return
  }

  const isAngular = /@angular\/core|@Component\b|@Injectable\b|@Directive\b/.test(source)
  const hasSubscribe = /\.subscribe\s*\(/.test(source)
  const isGuarded = /takeUntilDestroyed|takeUntil\s*\(|toSignal\s*\(/.test(source)

  if (isAngular && hasSubscribe && !isGuarded) {
    throw new Error(
      `[angular-rxjs-leak-guard] ${filePath}: RxJS .subscribe() with no takeUntilDestroyed/takeUntil/toSignal. Pipe takeUntilDestroyed(this.destroyRef) before .subscribe(), or prefer toSignal()/async pipe.`,
    )
  }
}

export const ClaudeCompat: Plugin = async ({ directory }) => {
  const instructionPaths = projectInstructionPaths(directory)
  const mcp = loadClaudeMcp(directory)

  return {
    config: (cfg) => {
      cfg.instructions = appendUnique(cfg.instructions, instructionPaths)
      if (mcp) cfg.mcp = { ...(cfg.mcp ?? {}), ...mcp }
    },
    "tool.execute.after": async (input, output) => {
      if (input.tool !== "edit" && input.tool !== "write") return
      warnOnAngularSubscribeLeak(getFilePath(input, output))
    },
  }
}

export default ClaudeCompat
