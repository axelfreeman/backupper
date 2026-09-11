// dsh skill plugin — registers the skill from SKILL.md (name + description + body).
import { readFileSync } from 'node:fs'

const NAME = "backupper"
const DESCRIPTION = "Set up free, encrypted, deduplicated backups of remote Linux servers, pulled from a Windows PC with Restic \u2014 tar-over-SSH streaming, zero software installed server-side, with size verification against silent partial-snapshot failures. Use when the user wants to back up VDS/VPS servers, protect against provider bans, \"\u043a\u0430\u043a \u043d\u0435 \u043f\u043e\u0442\u0435\u0440\u044f\u0442\u044c \u0432\u0441\u0451\", or automate backups. Works with any AI agent/model."

export const name = NAME

export function apply(ctx) {
  const raw = readFileSync(new URL('./SKILL.md', import.meta.url), 'utf8')
  const content = raw.replace(/^---[^\n]*\n[\s\S]*?\n---\s*\n?/, '').trim()
  ctx.skills.register({ name: NAME, description: DESCRIPTION, source: 'runtime', content })
}
