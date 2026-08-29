# AI foundation

## Retrieval before training

Trace should begin with local embeddings, message retrieval, and user-controlled
summaries. This is cheaper, reversible, and easier to delete than continuously
fine-tuning a model. Optional desktop fine-tuning can be evaluated later and
must never run silently.

## Providers

The application depends on an `AiProvider` port. Planned adapters are:

- an on-device model where hardware permits;
- Ollama or llama.cpp on the local network;
- a user-supplied OpenAI-compatible endpoint;
- OpenRouter with zero-data-retention routing requested.

Local is the default. Cloud execution requires a disclosure showing the rooms,
message count, attachments, and derived memory that will be sent. API keys are
stored in platform secure storage.

## Room participation

Private assistant answers stay local to the requesting user. A group assistant
uses a separate Matrix identity so membership, encryption access, prompts, and
responses are visible and auditable. The bot runs on a user's device and is
offline when that device is offline unless a future hosted service is chosen.

## Export

The export format will be versioned JSONL with a manifest. Every message record
must preserve room ID, event ID, timestamp, sender ID, whether the sender is the
exporting user, edits, reply relationships, and attachment references. Export
shows a disclaimer and provides independent attachment inclusion controls.
