/**
 * Regression guard for the deployed OMP hook `~/.omp/agent/hooks/pre/bash.ts`.
 *
 * That file is owned by home-git (mint-dotfiles tracks only `.omp/agent/config.yml`
 * and `models.yml` under `home/.omp/agent/`), so it is read from `$HOME` here
 * rather than from this package, and the suite skips when it is not deployed — the
 * same conditional shape the Chicago95 and copyq checks in `smoke.sh` use.
 *
 * What is pinned: a non-blank `bash.name` is service intent, so the revision drops
 * top-level `timeout` (any value, `0` included) and `async: true`, keeps
 * `async: false`, keeps `ready.timeout` whenever a readiness signal survives, and
 * removes a placeholder `ready` block carrying neither a log nor a usable port.
 * The revision must be a clone that only deletes fields — upstream revalidates it
 * against the bash schema, and the model's original arguments must not change.
 *
 * Run: `bun test tests/bash-service-hook.test.ts`
 */
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { describe, expect, test } from "bun:test";

const hookPath = join(homedir(), ".omp/agent/hooks/pre/bash.ts");
const deployed = existsSync(hookPath);

// A static import cannot work: the specifier is assembled from `$HOME` at runtime
// and the hook lives in home-git, so it is absent on a fresh checkout — importing
// it statically would fail this whole file before the skip below could apply.
const hookModule = deployed ? await import(hookPath) : undefined;

const { normalizeBashServiceInput, default: hookFactory } = hookModule ?? {};

/** Register the hook's single handler and hand it back for direct dispatch. */
function capturedHandler() {
	const handlers: Array<(event: Record<string, unknown>) => unknown> = [];
	hookFactory({ on: (_event, handler) => handlers.push(handler) });
	expect(handlers).toHaveLength(1);
	return handlers[0];
}

describe.skipIf(!deployed)("normalizeBashServiceInput", () => {
	test("leaves finite commands alone", () => {
		expect(normalizeBashServiceInput({ command: "ls -la", timeout: 30, async: false })).toBeUndefined();
	});

	test("leaves a blank service name alone (upstream treats it as finite)", () => {
		expect(normalizeBashServiceInput({ command: "ls", name: "", timeout: 30 })).toBeUndefined();
		expect(normalizeBashServiceInput({ command: "ls", name: "   ", timeout: 30 })).toBeUndefined();
		expect(normalizeBashServiceInput({ command: "ls", name: 7, timeout: 30 })).toBeUndefined();
	});

	test("drops timeout of any value beside a service name", () => {
		for (const timeout of [30, 0, 180]) {
			const out = normalizeBashServiceInput({ command: "server", name: "svc", timeout });
			expect(Object.hasOwn(out, "timeout")).toBeFalse();
			expect(out.command).toBe("server");
			expect(out.name).toBe("svc");
		}
	});

	test("drops async only when it is true", () => {
		const withTrue = normalizeBashServiceInput({ command: "server", name: "svc", timeout: 1, async: true });
		expect(Object.hasOwn(withTrue, "async")).toBeFalse();

		const withFalse = normalizeBashServiceInput({ command: "server", name: "svc", timeout: 1, async: false });
		expect(withFalse.async).toBe(false);
		expect(Object.hasOwn(withFalse, "timeout")).toBeFalse();
	});

	test("preserves async: false when another field forces a revision", () => {
		const out = normalizeBashServiceInput({ command: "server", name: "svc", async: false, ready: { port: 0 } });
		expect(out.async).toBe(false);
		expect(Object.hasOwn(out, "ready")).toBeFalse();
	});

	test("removes a materialized ready block with no readiness signal", () => {
		const out = normalizeBashServiceInput({
			command: "probe",
			name: "readiness-branches",
			timeout: 30,
			async: false,
			ready: { host: "", log: "", port: 0, timeout: 0 },
		});
		expect(Object.hasOwn(out, "timeout")).toBeFalse();
		expect(out.async).toBe(false);
		expect(Object.hasOwn(out, "ready")).toBeFalse();
		expect(out.name).toBe("readiness-branches");
	});

	test("keeps a usable ready block and its ready.timeout", () => {
		const withLog = normalizeBashServiceInput({
			command: "server",
			name: "svc",
			timeout: 30,
			ready: { log: "listening", port: 0, timeout: 12 },
		});
		expect(Object.hasOwn(withLog, "timeout")).toBeFalse();
		expect(withLog.ready).toEqual({ log: "listening", timeout: 12 });

		const withPort = normalizeBashServiceInput({
			command: "server",
			name: "svc",
			timeout: 30,
			ready: { port: 8899, timeout: 10 },
		});
		expect(Object.hasOwn(withPort, "timeout")).toBeFalse();
		expect(withPort.ready).toEqual({ port: 8899, timeout: 10 });
	});

	test("drops only an unusable port when a log carries readiness", () => {
		const out = normalizeBashServiceInput({
			command: "server",
			name: "svc",
			ready: { log: "ready", port: "8080", timeout: 10 },
		});
		expect(out.ready).toEqual({ log: "ready", timeout: 10 });
	});

	test("never returns a revision when nothing needs changing", () => {
		expect(normalizeBashServiceInput({ command: "server", name: "svc" })).toBeUndefined();
		expect(normalizeBashServiceInput({ command: "server", name: "svc", async: false })).toBeUndefined();
		expect(normalizeBashServiceInput({ command: "server", name: "svc", ready: { port: 8899 } })).toBeUndefined();
		expect(normalizeBashServiceInput({ command: "server", name: "svc", ready: null })).toBeUndefined();
	});

	test("never mutates the model's arguments", () => {
		const input = {
			command: "server",
			name: "svc",
			timeout: 30,
			async: true,
			cwd: "/tmp",
			pty: false,
			ready: { host: "", log: "", port: 0, timeout: 0 },
		};
		const before = structuredClone(input);
		const out = normalizeBashServiceInput(input);
		expect(input).toEqual(before);
		expect(out).not.toBe(input);
		expect(out.ready).not.toBe(input.ready);
		expect(out.cwd).toBe("/tmp");
		expect(out.pty).toBe(false);
	});
});

describe.skipIf(!deployed)("hook dispatch", () => {
	test("ignores every non-bash tool", () => {
		const handler = capturedHandler();
		expect(
			handler({ type: "tool_call", toolName: "read", toolCallId: "1", input: { name: "x", timeout: 1 } }),
		).toBeUndefined();
	});

	test("returns the full revised input for a bash service call", () => {
		const handler = capturedHandler();
		const result = handler({
			type: "tool_call",
			toolName: "bash",
			toolCallId: "1",
			input: { command: "server", name: "svc", timeout: 0, ready: { port: 0, timeout: 0 } },
		});
		expect(result.block).toBeUndefined();
		expect(result.input).toEqual({ command: "server", name: "svc" });
	});

	test("returns nothing for a bash call that needs no revision", () => {
		const handler = capturedHandler();
		expect(
			handler({ type: "tool_call", toolName: "bash", toolCallId: "1", input: { command: "ls", timeout: 5 } }),
		).toBeUndefined();
	});

	test("fails open instead of blocking when the input is not an object", () => {
		const handler = capturedHandler();
		expect(handler({ type: "tool_call", toolName: "bash", toolCallId: "1", input: null })).toBeUndefined();
	});
});
