import { INodeType, INodeExecutionData, IExecuteFunctions,INodeTypeDescription, NodeConnectionTypes, INodeInputConfiguration, INodeOutputConfiguration, NodeOperationError } from 'n8n-workflow';
import { join } from 'path';
import { platform } from 'os';
import { getBrowserExecutablePath } from './utils';
import { handleOperation } from './operations';
import { IBrowserOptions } from './types';
import { installBrowser } from '../scripts/setup-browsers';
import { BrowserType } from './config';
import { getOrCreateSession, closeSession } from './sessionManager';

export class Playwright implements INodeType {
    description : INodeTypeDescription = {
    displayName: 'Playwright',
    name: 'playwright',
    icon: 'file:playwright.svg',
    group: ['transform'],
    version: 1,
    subtitle: '={{$parameter["operation"]}}',
    description: 'Automate browser actions using Playwright',
    defaults: {
        name: 'Playwright',
    },
    // eslint-disable-next-line n8n-nodes-base/node-class-description-inputs-wrong-regular-node
    inputs: [
        {
            displayName: 'Input',
            type: NodeConnectionTypes.Main,
        } as INodeInputConfiguration,
    ],
    // eslint-disable-next-line n8n-nodes-base/node-class-description-outputs-wrong
    outputs: [
        {
            displayName: 'Output',
            type: NodeConnectionTypes.Main,
        } as INodeOutputConfiguration,
    ],

    properties: [
        {
            displayName: 'Operation',
            name: 'operation',
            type: 'options',
            noDataExpression: true,
            options: [
                {
                    name: 'Click Element',
                    value: 'clickElement',
                    description: 'Click on an element',
																				action: 'Click on an element',
                },
                {
                    name: 'Close Session',
                    value: 'closeSession',
                    description: 'Close a browser session opened with a Session ID, freeing its resources',
                    action: 'Close a browser session',
                },
                {
                    name: 'Fill Form',
                    value: 'fillForm',
                    description: 'Fill a form field',
																				action: 'Fill a form field',
                },
                {
                    name: 'Get Text',
                    value: 'getText',
                    description: 'Get text from an element',
																				action: 'Get text from an element',
                },
                {
                    name: 'Navigate',
                    value: 'navigate',
                    description: 'Navigate to a URL',
																				action: 'Navigate to a URL',
                },
                {
                    name: 'Take Screenshot',
                    value: 'takeScreenshot',
                    description: 'Take a screenshot of a webpage',
																				action: 'Take a screenshot of a webpage',
                },
            ],
            default: 'navigate',
        },

        {
            displayName: 'Session ID',
            name: 'sessionId',
            type: 'string',
            default: '',
            placeholder: 'my-checkout-flow',
            description: 'Reuse one browser across multiple Playwright nodes by giving them the same Session ID -- e.g. fill a form, click submit (which navigates), then continue filling the next page in a later node. Leave empty for a fresh, single-use browser that closes automatically after this node. A session left idle for 10 minutes is closed automatically; use "Close Session" to free it sooner. Only a limited number of NEW sessions can be open at once (deployment-configured, default 3) -- creating one beyond that fails with a clear error; enable "Retry On Fail" with a "Wait Between Tries" delay on this node\'s settings to retry once a slot frees up. Reusing an existing Session ID is never blocked by this limit.',
        },

        {
            displayName: 'URL',
            name: 'url',
            type: 'string',
            default: '',
            placeholder: 'https://example.com',
            description: 'The URL to navigate to. When continuing an existing Session ID, leave empty to operate on the page as the session already left it (e.g. after a previous node\'s submit click navigated it) without re-navigating.',
            displayOptions: {
                show: {
                    operation: ['navigate', 'takeScreenshot', 'getText', 'clickElement', 'fillForm'],
                },
            },
        },
				{
    displayName: 'Property Name',
    name: 'dataPropertyName',
    type: 'string',
    required: true,
    default: 'screenshot',
    description: 'Name of the binary property in which to store the screenshot data',
    displayOptions: {
        show: {
            operation: ['takeScreenshot'],
        },
    },
},
        {
            displayName: 'Selector',
            name: 'selector',
            type: 'string',
            default: '',
            placeholder: '#submit-button',
            description: 'CSS selector for the element',
            displayOptions: {
                show: {
                    operation: ['getText', 'clickElement', 'fillForm'],
                },
            },
            required: true,
        },
        {
            displayName: 'Value',
            name: 'value',
            type: 'string',
            default: '',
            description: 'Value to fill in the form field',
            displayOptions: {
                show: {
                    operation: ['fillForm'],
                },
            },
            required: true,
        },
        {
            displayName: 'Browser',
            name: 'browser',
            type: 'options',
            options: [
                {
                    name: 'Chromium',
                    value: 'chromium',
                },
                {
                    name: 'Firefox',
                    value: 'firefox',
                },
                {
                    name: 'Webkit',
                    value: 'webkit',
                },
            ],
            default: 'chromium',
        },
        {
            displayName: 'Browser Launch Options',
            name: 'browserOptions',
            type: 'collection',
            placeholder: 'Add Option',
            default: {},
            options: [
                {
                    displayName: 'Headless',
                    name: 'headless',
                    type: 'boolean',
                    default: true,
                    description: 'Whether to run browser in headless mode',
                },
                {
                    displayName: 'Slow Motion',
                    name: 'slowMo',
                    type: 'number',
                    default: 0,
                    description: 'Slows down operations by the specified amount of milliseconds',
                }
            ],
        },
        {
            displayName: 'Screenshot Options',
            name: 'screenshotOptions',
            type: 'collection',
            placeholder: 'Add Option',
            default: {},
            displayOptions: {
                show: {
                    operation: ['takeScreenshot'],
                },
            },
            options: [
                {
                    displayName: 'Full Page',
                    name: 'fullPage',
                    type: 'boolean',
                    default: false,
                    description: 'Whether to take a screenshot of the full scrollable page',
                },
                {
                    displayName: 'Path',
                    name: 'path',
                    type: 'string',
                    default: '',
                    description: 'The file path to save the screenshot to',
                },
            ],
        },
    ],
};

    async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
        const items = this.getInputData();
        const returnData: INodeExecutionData[] = [];

        for (let i = 0; i < items.length; i++) {
            const operation = this.getNodeParameter('operation', i) as string;
            const sessionId = (this.getNodeParameter('sessionId', i) as string) || '';

            if (operation === 'closeSession') {
                try {
                    const closed = await closeSession(sessionId);
                    returnData.push({ json: { success: true, closed } });
                } catch (error) {
                    if (this.continueOnFail()) {
                        returnData.push({ json: { error: error.message } });
                        continue;
                    }
                    throw error;
                }
                continue;
            }

            const url = (this.getNodeParameter('url', i) as string) || '';
            const browserType = this.getNodeParameter('browser', i) as BrowserType;
            const browserOptions = this.getNodeParameter('browserOptions', i) as IBrowserOptions;
            const usingSession = sessionId !== '';

            // Declared outside the try so the finally block below can always
            // reach it, even if launch() itself never assigns it (e.g. the
            // executablePath resolution/install throws first). Only ever set
            // for an EPHEMERAL (no Session ID) browser -- a session-mode
            // browser is intentionally left open across node executions, so
            // it must never be assigned here or the finally block would close
            // it out from under the next node reusing the same Session ID.
            let browserRef: import('playwright').Browser | undefined;
            let isNewSession = true;

            try {
                const playwright = require('playwright');
                const browsersPath = join(__dirname, '..', 'browsers');

                // Resolves the executable path (and installs the browser as a
                // fallback) lazily, only when actually launching -- reusing an
                // existing session's page below never needs to touch this.
                const launch = async () => {
                    let executablePath;
                    try {
                        executablePath = getBrowserExecutablePath(browserType, browsersPath);
                    } catch (error) {
                        console.error(`Browser path error: ${error.message}`);
                        // Try to install missing browser
                        await installBrowser(browserType);
                        executablePath = getBrowserExecutablePath(browserType, browsersPath);
                    }

                    console.log(`Launching browser from: ${executablePath}`);

                    return playwright[browserType].launch({
                        headless: browserOptions.headless !== false,
                        slowMo: browserOptions.slowMo || 0,
                        executablePath,
                    });
                };

                let page: import('playwright').Page;

                if (usingSession) {
                    const { session, isNew } = await getOrCreateSession(sessionId, browserType, launch);
                    page = session.page;
                    isNewSession = isNew;
                } else {
                    const browser = await launch();
                    browserRef = browser;
                    const context = await browser.newContext();
                    page = await context.newPage();
                }

                // Only navigate when a URL was actually given -- a node
                // continuing an existing session usually wants to operate on
                // whatever page it's already on (e.g. after a previous node's
                // submit click navigated it), not jump back to a fixed URL.
                if (url) {
                    await page.goto(url);
                } else if (!usingSession || isNewSession) {
                    throw new NodeOperationError(this.getNode(), 'URL is required unless continuing an existing Session ID.', { itemIndex: i });
                }

                const result = await handleOperation(operation, page, this, i);
                returnData.push(result);
            } catch (error) {
                console.error(`Browser launch error:`, error);
                if (this.continueOnFail()) {
                    returnData.push({
                        json: {
                            error: error.message,
                            browserType,
                            os: platform(),
                        },
                    });
                    continue;
                }
                throw error;
            } finally {
                // Without this, any error thrown after launch() (a hung/failed
                // page.goto, a missing selector, etc.) leaked the entire
                // Chromium process tree forever -- browser.close() previously
                // only ran on the success path. Swallow close() failures: the
                // browser may already be dead/unreachable, and a close error
                // must never mask the real error from the try block above.
                // Session-mode browsers are deliberately NOT closed here --
                // they're meant to outlive this node; sessionManager's own
                // idle reaper (and the explicit "Close Session" operation)
                // are what eventually close those.
                if (browserRef) {
                    await browserRef.close().catch((closeError) => {
                        console.error(`Browser close error:`, closeError);
                    });
                }
            }
        }

        return [returnData];
    }
}
