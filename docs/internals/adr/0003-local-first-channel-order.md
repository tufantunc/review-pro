# 0003: Verify external premises local-first, and record which channel settled it

Status: accepted
Date: 2026-08-25

## Context

When a diff's rationale cites an external artifact ("upstream bug fixed in the new version"), the reviewer that owns the claim must check it. "Go outside the repo" is two different acts: reading the dependency source the build actually resolved to, and reaching for the network. In [pilot case 2](../../../studies/2026-08-copilot-pr-pilot/FINDINGS-case2.md), both halves of the centerpiece finding were visible in the installed package source, and the one claim that went unsettled was blocked by the package being absent from the local cache, not by lack of network.

## Decision

A fixed channel order, stopping at the first channel that settles the premise: the locally resolved dependency source, then lockfile and manifest, then the network, then nothing. The reviewer records which channel settled it, because a network answer can differ tomorrow and a reader must be able to tell a durable verification from a perishable one.

Rejected: an undifferentiated "check upstream" mandate (unreproducible and slower); network-first (the local source is where "at the pinned version" is literally true).

## Consequences

Reviews touch the network rarely and say so when they do. Air-gapped environments degrade to an explicit "unverified: <reason>" rather than a silent skip. Design: [2026-08-25-external-premise-verification-design.md](../../superpowers/specs/2026-08-25-external-premise-verification-design.md); acceptance: [REPLAY-case2.md](../../../studies/2026-08-copilot-pr-pilot/REPLAY-case2.md).
