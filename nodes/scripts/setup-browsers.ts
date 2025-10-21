import { mkdirSync, existsSync, readdirSync, rmSync, cpSync } from 'fs';
import { join } from 'path';
import { execSync } from 'child_process';
import { platform } from 'os';
import { BrowserType } from '../playwright/config';

async function setupBrowsers() {
	try {
			// 1. First log the environment
			console.log('Current working directory:', process.cwd());
			console.log('Operating System:', platform());
			console.log('Node version:', process.version);

			// Check for system browsers (Alpine Linux compatibility)
			const systemChromium = '/usr/bin/chromium-browser';
			const systemFirefox = '/usr/bin/firefox';

			if (existsSync(systemChromium) && existsSync(systemFirefox)) {
					console.log('\nSystem browsers detected! Using Alpine-compatible browsers.');

					const browsersPath = join(__dirname, '..', 'browsers');

					// Clean and create browsers directory
					if (existsSync(browsersPath)) {
							rmSync(browsersPath, { recursive: true, force: true });
					}
					mkdirSync(browsersPath, { recursive: true });

					// Create symlinks to system browsers
					// Chromium - version 1194 is expected
					const chromiumDir = join(browsersPath, 'chromium-1194');
					mkdirSync(join(chromiumDir, 'chrome-linux'), { recursive: true });
					execSync(`ln -sf ${systemChromium} ${join(chromiumDir, 'chrome-linux', 'chrome')}`);
					console.log('Linked system Chromium to:', join(chromiumDir, 'chrome-linux', 'chrome'));

					// Firefox - version 1491 is expected
					const firefoxDir = join(browsersPath, 'firefox-1491');
					mkdirSync(join(firefoxDir, 'firefox'), { recursive: true });
					execSync(`ln -sf ${systemFirefox} ${join(firefoxDir, 'firefox', 'firefox')}`);
					console.log('Linked system Firefox to:', join(firefoxDir, 'firefox', 'firefox'));

					console.log('\nSystem browser setup completed successfully!');
					return; // Exit early - no need to download browsers
			}

			// 2. Determine paths for non-Alpine systems
			const os = platform();
			const sourcePath = os === 'win32'
					? join(process.env.USERPROFILE || '', 'AppData', 'Local', 'ms-playwright')
					: join(process.env.HOME || '', '.cache', 'ms-playwright');

			const browsersPath = join(__dirname, '..', 'browsers');

			console.log('\nPaths:');
			console.log('Source path:', sourcePath);
			console.log('Destination path:', browsersPath);

			// 3. Check if source exists
			if (!existsSync(sourcePath)) {
					console.log('\nInstalling Playwright browsers...');
					execSync('npx --yes playwright install', { stdio: 'inherit' });
			}

			// 4. Clean destination if it exists
			if (existsSync(browsersPath)) {
					console.log('\nCleaning existing browsers directory...');
					rmSync(browsersPath, { recursive: true, force: true });
			}

			// 5. Create fresh browsers directory
			console.log('Creating browsers directory...');
			mkdirSync(browsersPath, { recursive: true });

			// 6. Copy browser files with detailed logging
			console.log('\nCopying browser files...');
			const files = readdirSync(sourcePath);

			for (const file of files) {
					// Only copy browser directories we need
					if (file.startsWith('chromium-') ||
							file.startsWith('firefox-') ||
							file.startsWith('webkit')) {

							const sourceFull = join(sourcePath, file);
							const destFull = join(browsersPath, file);

							console.log(`Copying ${file}...`);
							cpSync(sourceFull, destFull, { recursive: true });
					}
			}

			// 7. Verify installation
			console.log('\nVerifying installation...');
			const installedFiles = readdirSync(browsersPath);
			console.log('Installed browsers:', installedFiles);

			// 8. Verify each browser executable
			const browsers: BrowserType[] = ['chromium', 'firefox', 'webkit'];
			for (const browserType of browsers) {
					const browserDir = installedFiles.find(f => f.startsWith(browserType));

					if (!browserDir) {
							console.log(`\nInstalling ${browserType}...`);
							await installBrowser(browserType);
					}
			}

			console.log('\nBrowser setup completed successfully!');
	} catch (error) {
			console.error('\nError during browser setup:', error);
			process.exit(1);
	}
}

export async function installBrowser(browserType: BrowserType) {
    try {
        console.log(`Installing ${browserType}...`);
        execSync(`PLAYWRIGHT_BROWSERS_PATH=~/.n8n/nodes/node_modules/n8n-nodes-playwright/dist/nodes/browsers npx --yes playwright install ${browserType}`, { stdio: 'inherit' });
    } catch (error) {
        console.error(`Failed to install ${browserType}:`, error);
    }
}

// Run the setup
console.log('Starting browser setup...\n');
setupBrowsers().catch(error => {
    console.error('Unhandled error:', error);
    process.exit(1);
});
