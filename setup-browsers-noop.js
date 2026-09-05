"use strict";
Object.defineProperty(exports, "__esModule", { value: true });

// Neutered at image build time (see dockerfile). The original file
// unconditionally wiped n8n-nodes-playwright's browsers directory and
// re-ran `npx playwright install` (chromium+firefox+webkit, ~400MB,
// incompatible glibc builds on this musl image) EVERY container start --
// n8n invokes this script directly at startup regardless of how the
// package was installed, so --ignore-scripts at npm-install time doesn't
// stop it. Browsers are baked in via the chromium-alpine-system symlink
// instead; this stub replaces the original file entirely so nothing
// destructive runs no matter how it gets invoked.
exports.installBrowser = async function installBrowser() {};
