- severity: Low
  category: security.authz
  file: src/routes/internal.js
  line: 5
  title: The new role-change endpoint has no authentication or admin check of its own and depends only on the gateway ACL
  evidence: |
    // src/routes/internal.js
    internal.post("/users/:id/role", (req, res) => {
      const ok = db.setRole(req.params.id, req.body.role);
      return ok ? res.json({ ok: true }) : res.status(404).json({ error: "not found" });
    });
    // src/app.js:8
    app.use("/internal", internal);
    // infra/gateway/kong.yml:3-12
    - name: accounts-internal
      url: http://accounts-service:8080/internal
      routes:
        - name: internal
          paths: ["/internal"]
      plugins:
        - name: jwt
        - name: acl
          config:
            allow: ["admin"]
  evidence_refs: [src/app.js:8, infra/gateway/kong.yml:3-12, src/middleware/auth.js:2-10, README.md:6-8]
  impact: |
    The lower-trust actor is any caller that can reach accounts-service:8080 without going through Kong, such as another workload on the internal network or an SSRF sink in another service. That caller controls the target user id (req.params.id) and any role string (req.body.role). The control that should stop them is authentication plus the admin check. Behind the gateway, that control exists. Kong applies `jwt` and `acl allow: ["admin"]` to the `/internal` prefix. Kong's prefix match is at least as strict as Express's mount, so `/internalx` reaches Express as `/internalx` and does not hit this router. So the gateway path is covered. The gap is at the service boundary. The handler mounts no `requireUser`/`requireAdmin`, even though both already exist in src/middleware/auth.js. A direct request can therefore set any user's role, including `admin`, and that is privilege escalation. I could not show from this repo that anyone can reach the service without Kong. Whether they can depends on network policy that is not committed here. Whether a public Kong route on this service has a catch-all path also depends on config outside the repo. The public routes are only described in README.md:6-7. If such a route exists, `/Internal/...` would miss Kong's case-sensitive `/internal` route and still reach this router, because Express routing is case-insensitive by default. That would make this a gateway bypass and High. Without it, this is a missing second layer (Low).
  remedy: |
    Mount the existing middleware on the router as defense in depth: `internal.use(requireUser, requireAdmin)`, or `app.use("/internal", requireUser, requireAdmin, internal)`. Alternatively, verify the gateway-issued JWT inside the service. Allowlist `req.body.role` against the known roles. Check the public Kong routes for accounts-service and confirm none is a `/` catch-all. If a service-level check is not added, enable `app.set("case sensitive routing", true)` so a different-case path cannot reach `/internal`.
  confidence: medium
  overlap_hints: [backend.validation]
