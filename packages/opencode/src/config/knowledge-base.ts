import { Schema } from "effect"

export const Info = Schema.Struct({
  path: Schema.optional(Schema.String).annotate({
    description: "Absolute, ~/ or workspace-relative path to knowledge base directory",
  }),
  instructions: Schema.optional(Schema.String).annotate({
    description: "Path to a .md file with search guidance, auto-injected into system prompt",
  }),
}).annotate({ identifier: "KnowledgeBaseConfig" })

export type Info = Schema.Schema.Type<typeof Info>

export * as ConfigKnowledgeBase from "./knowledge-base"