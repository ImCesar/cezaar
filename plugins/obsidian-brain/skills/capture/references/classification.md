# Classification Reference

Rules for classifying user input into capture types. The capture skill references this file when classification is ambiguous.

## Types and Signal Patterns

### Todo

Actionable tasks — something the user needs to **do**.

**Signal words:** fix, build, create, set up, implement, add, remove, update, deploy, send, schedule, write (when producing a deliverable), refactor, migrate, clean up, ship, finish, complete, submit, publish, configure, install

**Signal phrases:**
- "I need to..."
- "Remind me to..."
- "Don't forget to..."
- "I should..."
- "Let me..." (followed by an action)
- "I have to..."
- "Make sure to..."
- "TODO:"

**Examples:**
- "Fix the login bug" → todo
- "I need to update the API docs before Friday" → todo
- "Remind me to cancel the subscription" → todo
- "Deploy the new version to staging" → todo
- "Write the quarterly report" → todo (deliverable, not exploration)

### Idea

Creative, exploratory, or speculative thoughts — something the user is **imagining**.

**Signal words:** maybe, could, might, possibly, imagine, envision, brainstorm, concept, experiment, prototype, rethink, redesign

**Signal phrases:**
- "What if we..."
- "I was thinking about..."
- "It would be cool if..."
- "We could..."
- "Wouldn't it be nice if..."
- "I wonder if we should..."
- "Here's a thought..."
- "Crazy idea but..."

**Examples:**
- "What if we used WebSockets instead of polling?" → idea
- "It would be cool if the dashboard had a dark mode" → idea
- "I was thinking about splitting the monolith into services" → idea
- "Maybe we should try Rust for the CLI" → idea

### Question

Seeking knowledge or answers — something the user wants to **understand**.

**Signal words:** how, why, what, when, where, which, who, does, is, can, could, would, should (when asking, not deciding)

**Signal phrases:**
- "How does..."
- "Why is..."
- "What's the difference between..."
- "Is it possible to..."
- "Can you explain..."
- "What happens when..."
- "I don't understand..."

**Examples:**
- "How does OAuth2 work?" → question
- "Why is the build so slow?" → question
- "What's the difference between REST and GraphQL?" → question
- "Is it possible to run Postgres in Lambda?" → question

### Research

Investigation spikes — something the user wants to **dig into** over time.

**Signal words:** research, investigate, explore, evaluate, compare, benchmark, assess, survey, audit, review (when analyzing options), spike, deep-dive, look into, dig into

**Signal phrases:**
- "I need to research..."
- "Look into..."
- "Explore options for..."
- "Let's evaluate..."
- "We should compare..."
- "Do a spike on..."
- "I want to deep-dive into..."

**Examples:**
- "Research state management options for the new app" → research
- "Look into whether we can switch to Bun" → research
- "Explore options for CI/CD — GitHub Actions vs CircleCI" → research
- "I need to investigate the memory leak in production" → research

## Ambiguity Resolution

When input matches multiple types, use these tiebreakers in order:

### 1. Explicit type words win

If the user literally says a type word, honor it:
- "I need to **research** how to fix the login bug" → research (not todo)
- "I have a **question** about deployment" → question (not research)
- "Just an **idea** — we should rewrite the auth service" → idea (not todo)

### 2. Action vs exploration

If the input describes a concrete, completable action → todo.
If it describes open-ended exploration → research or idea.

- "Set up monitoring for the API" → todo (concrete action)
- "Figure out what monitoring solution to use" → research (open-ended)

### 3. Asking vs investigating

If the input is a single question seeking a fact → question.
If it implies sustained investigation across multiple sources → research.

- "What's the latest version of Node?" → question (quick answer)
- "What are the tradeoffs between Node and Deno for our use case?" → research (sustained investigation)

### 4. When still ambiguous, capture as-is

If you genuinely can't decide, pick the type that feels closest and tell the user:

> I captured this as a **research** item since it sounds like it needs some digging. If you meant it as a todo, just let me know and I'll reclassify it.

Never block on classification. Capturing something in the wrong bucket is better than not capturing it at all. The triage skill exists to fix misclassifications later.

## Edge Cases

| Input | Type | Reasoning |
|-------|------|-----------|
| "I need to research how to fix the login bug" | research | Explicit "research" overrides the action verb "fix" |
| "Fix the login bug" | todo | Direct imperative action |
| "What if we used a different auth library?" | idea | Speculative, exploratory "what if" |
| "How does OAuth2 work?" | question | Seeking factual knowledge |
| "Look into OAuth2 for our auth flow" | research | "Look into" signals investigation |
| "I should probably look into OAuth2" | research | "Look into" still signals investigation despite hedging |
| "OAuth2" | idea | Single word/phrase with no verb — capture as idea (lowest commitment) |
| "The build is broken" | todo | Implied action: fix it |
| "Why is the build broken?" | question | Asking for explanation, not action |
| "We need to figure out why builds keep breaking" | research | "Figure out" + recurring problem = investigation |
