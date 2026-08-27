# Microsandbox vs. Workmux Sandbox

## Summary of trade‑offs

| Aspect | Microsandbox | Workmux (Container) | Workmux (Lima) |
|--------|--------------|--------------------|----------------|
| Isolation | Strong hardware microVM (Kata/Firecracker) | Process‑level namespaces | VM‑level (Lima) |
| Persistence | Transient, can detach | Ephemeral, new container per session | Persistent VMs |
| Toolchain | Image‑centric; you bake tooling | Custom Dockerfile / host‑command proxy | Built‑in Nix/Devbox, custom provisioning |
| Network | No built‑in filtering | Domain‑allowlist via iptables | Unrestricted |
| Secrets | No leakage; secrets are confined | Shared via mounts; sandbox blocks host keys | Same but with VM isolation |
| Startup | ~< 100 ms | ~50 ms | 1–2 s first run, < 200 ms thereafter |
| Platforms | Linux, macOS, Windows (KVM/WHP) | Docker/Podman on Linux/macOS, Apple Container | Linux & macOS |
| Use‑case | Untrusted AI workloads, audit‑safe code | CI jobs, tooling, quick experiments | Persistent dev env w/ Nix/Devbox |

## Recommendation
If isolation is paramount (e.g., running untrusted scripts or AI prompts) **Microsandbox** is the best fit. If you already run Workmux and need persistent VMs or Nix tooling, choose the **Lima** backend. For lightweight, repeatable container runs, the **container** backend suffices.
