import { Browser, BrowserContext, Page } from 'playwright';
import { BrowserType } from './config';

export interface BrowserSession {
    browser: Browser;
    context: BrowserContext;
    page: Page;
    browserType: BrowserType;
    lastUsedAt: number;
}

// Module-scope: persists across separate Playwright node executions within
// the same running n8n process, which is what lets a "fill form -> submit
// (navigates) -> fill the next page's form" flow share one real browser/page
// across separate node instances in a workflow. Does NOT persist across
// separate n8n worker processes (queue-mode workers each get their own map)
// -- a session must stay pinned to whichever worker created it.
const sessions = new Map<string, BrowserSession>();

const IDLE_TIMEOUT_MS = Number(process.env.PLAYWRIGHT_SESSION_IDLE_TIMEOUT_MS) || 10 * 60 * 1000;
const SWEEP_INTERVAL_MS = 60 * 1000;

// Each open session pins a real Chromium process tree in memory for as long
// as it lives (until "Close Session", or the idle reaper above). Uncapped,
// enough concurrent sessions on a memory-constrained container (e.g. a small
// VPS) can OOM the whole n8n process -- exactly the failure mode the
// try/finally fix in Playwright.node.ts addressed for the ephemeral case.
// Capping new-session creation is the equivalent guard for session mode: once
// at the limit, further NEW sessions fail fast with a distinguishable error
// instead of piling on more browsers than the host can hold. Reusing an
// EXISTING session is never blocked by this -- see getOrCreateSession below.
// Tune per-deployment via env var; there's no universally correct default,
// only "however many concurrent Chromium instances this container's memory
// limit can actually hold" (rule of thumb: ~150-300MB each, plus n8n's own
// baseline -- e.g. a 1024M-limited container might reasonably hold 2-3).
const MAX_SESSIONS = Number(process.env.PLAYWRIGHT_MAX_SESSIONS) || 3;

export class SessionLimitError extends Error {
    constructor(limit: number) {
        super(
            `Playwright session limit reached (${limit} active session${limit === 1 ? '' : 's'}). ` +
            `Close an existing session (the "Close Session" operation) or wait for one to idle out, then try again. ` +
            `Enable "Retry On Fail" with a "Wait Between Tries" delay on this node's settings to retry automatically once a slot frees up -- ` +
            `a session only frees up from something ELSE happening (another node's Close Session call, or the idle reaper), so retrying immediately in a tight loop won't help; a real wait between tries is what gives that time to happen.`,
        );
        this.name = 'SessionLimitError';
    }
}

let reaperStarted = false;

// Safety net for the exact leak class fixed in Playwright.node.ts's
// try/finally: a session-mode browser is deliberately left open across node
// executions, so if a workflow errors out (or is just poorly designed)
// before ever calling "Close Session", nothing else would ever close it.
function startReaper(): void {
    if (reaperStarted) return;
    reaperStarted = true;
    const timer = setInterval(() => {
        const now = Date.now();
        for (const [id, session] of sessions) {
            if (now - session.lastUsedAt > IDLE_TIMEOUT_MS) {
                console.warn(
                    `Playwright session "${id}" idle for over ${IDLE_TIMEOUT_MS}ms -- closing automatically. Use the "Close Session" operation explicitly instead of relying on this safety net.`,
                );
                sessions.delete(id);
                session.browser.close().catch((error) => {
                    console.error(`Error closing idle Playwright session "${id}":`, error);
                });
            }
        }
    }, SWEEP_INTERVAL_MS);
    // Don't let this timer keep the Node process alive on its own.
    timer.unref?.();
}

export async function getOrCreateSession(
    sessionId: string,
    browserType: BrowserType,
    launch: () => Promise<Browser>,
): Promise<{ session: BrowserSession; isNew: boolean }> {
    startReaper();

    const existing = sessions.get(sessionId);
    if (existing) {
        if (existing.browserType !== browserType) {
            throw new Error(
                `Playwright session "${sessionId}" was created with browser "${existing.browserType}", but this node requested "${browserType}". Use a different Session ID, or close the existing session first.`,
            );
        }
        existing.lastUsedAt = Date.now();
        return { session: existing, isNew: false };
    }

    if (sessions.size >= MAX_SESSIONS) {
        throw new SessionLimitError(MAX_SESSIONS);
    }

    const browser = await launch();
    const context = await browser.newContext();
    const page = await context.newPage();
    const session: BrowserSession = { browser, context, page, browserType, lastUsedAt: Date.now() };
    sessions.set(sessionId, session);
    return { session, isNew: true };
}

export async function closeSession(sessionId: string): Promise<boolean> {
    const session = sessions.get(sessionId);
    if (!session) {
        return false;
    }
    sessions.delete(sessionId);
    await session.browser.close();
    return true;
}
