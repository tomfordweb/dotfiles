---
name: e2e
description: Write or review Playwright e2e tests for the  project, enforcing all project rules — 5s timeout cap, testId directive, storageState auth, POM pattern, getByTestId selectors. USE WHEN user types /e2e, says "write a playwright test", "add e2e coverage", or "write an e2e spec".
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - AskUserQuestion
---

# /e2e

You are writing or reviewing Playwright e2e tests for the project. Follow all rules below without exception. These are not preferences — they are hard project constraints.

## Project e2e structure

```
e2e/
  smoke.spec.ts
  auth.setup.ts
  global-setup.ts
  fixtures/
    index.ts              ← extend base test here; register POM fixtures
    poms/
      {feature}.ts        ← one POM class per page/feature
  public/
    {name}.spec.ts
  dashboard/
    {name}.spec.ts
  .auth/
    artist.json           ← storageState written by auth.setup.ts
```

---

## Hard rules — no exceptions

### 1. Timeout cap: 5 000 ms maximum

**Every** `waitFor`, `waitForFunction`, `waitForURL`, `waitForResponse`, `expect.poll`, and `test.afterAll` that accepts a timeout must use `{ timeout: 5_000 }` or less. Never exceed 5 000.

```typescript
// CORRECT
await element.waitFor({ timeout: 5_000 });
await page.waitForURL(/\/dashboard/, { timeout: 5_000 });
await page.waitForFunction(() => condition, { timeout: 5_000 });
await page.waitForResponse((r) => r.url().includes('/api'), { timeout: 5_000 });

// WRONG — never do this
await element.waitFor({ timeout: 10_000 });
await element.waitFor();  // implicit timeout from config is fine; explicit must cap at 5k
```

If an owner-approved exception exists, add an inline comment on that specific line. Never exceed 5 000 without explicit approval documented inline.

### 2. testId directive — use `[testId]` in templates, `getByTestId()` in tests

The `TestIdDirective` writes `data-test-id` (with a dash). Playwright config sets `testIdAttribute: 'data-test-id'`.

**In Angular templates:**
```html
<!-- CORRECT -->
<div testId="booking-row">
<button testId="submit-btn">

<!-- WRONG — never do this -->
<div data-testid="booking-row">
<div data-test-id="booking-row">
```

Component must import `TestIdDirective` in its `imports` array.

**In Playwright tests / POMs:**
```typescript
// CORRECT
page.getByTestId('booking-row')
row.getByTestId('status-badge')

// WRONG
page.locator('[data-testid="booking-row"]')
page.locator('[data-test-id="booking-row"]')
```

**Exception:** `waitForFunction` callbacks run in browser context and must use `document.querySelectorAll('[data-test-id="..."]')` (with dash) directly — `getByTestId` is not available there.

### 3. Auth via storageState — never Playwright MCP for authenticated flows

```typescript
const AUTH_FILE = 'e2e/.auth/artist.json';

// Approach A — per describe block
test.describe.serial('dashboard tests', () => {
  test.use({ storageState: AUTH_FILE });
  // ...
});

// Approach B — per test via browser.newContext
test.beforeAll(async ({ browser }) => {
  const ctx = await browser.newContext({ storageState: AUTH_FILE });
  const page = await ctx.newPage();
  // ...
  await page.close();
  await ctx.close();
});
```

**Never** use the Playwright MCP server to test authenticated flows — it has no access to Clerk session tokens. Use the e2e test suite (`npm run e2e`) instead.

### 4. POM pattern — one class per feature/page

Each page or feature gets a POM class in `e2e/fixtures/poms/{feature}.ts`.

```typescript
// e2e/fixtures/poms/bookings-page.ts
import type { Page, Locator } from '@playwright/test';

export class BookingsPage {
  readonly heading: Locator;
  readonly bookingRows: Locator;

  constructor(private page: Page) {
    this.heading = page.getByTestId('page-heading');
    this.bookingRows = page.getByTestId('booking-row');
  }

  async goto() {
    await this.page.goto('/bookings');
    await this.heading.waitFor({ timeout: 5_000 });
  }
}
```

Register in `e2e/fixtures/index.ts`:
```typescript
bookingsPage: async ({ page }, use) => {
  await use(new BookingsPage(page));
},
```

### 5. waitForResponse — set up listener BEFORE the action

```typescript
// CORRECT
const responsePromise = page.waitForResponse(
  (r) => r.url().includes('/api/v1/bookings') && r.request().method() === 'GET',
  { timeout: 5_000 },
);
await page.click('button[type="submit"]');
const response = await responsePromise;

// WRONG — race condition
await page.click('button[type="submit"]');
await page.waitForResponse((r) => r.url().includes('/api'));
```

### 6. No raw `data-testid` selectors as strings in tests

```typescript
// WRONG
page.locator('[data-testid="foo"]')
page.locator('[data-test-id="foo"]')

// CORRECT
page.getByTestId('foo')
```

---

## Test file structure

```typescript
import { test, expect } from '../fixtures';

const AUTH_FILE = 'e2e/.auth/artist.json';

test.describe.serial('feature name', () => {
  test.use({ storageState: AUTH_FILE });

  let sharedId: string;

  test.beforeAll(async ({ browser }) => {
    const ctx = await browser.newContext({ storageState: AUTH_FILE });
    const page = await ctx.newPage();
    // seed data
    await page.close();
    await ctx.close();
  });

  test.afterAll(async ({ browser }) => {
    // cleanup
  }, { timeout: 5_000 });

  test('does the thing', async ({ page, featurePage }) => {
    await featurePage.goto();
    await expect(featurePage.heading).toBeVisible();
  });
});
```

---

## Before writing tests

1. Read the relevant page component to understand what `testId` attributes exist.
2. Check `e2e/fixtures/index.ts` — the POM may already be registered.
3. Check existing POMs in `e2e/fixtures/poms/` — extend rather than duplicate.
4. Confirm the feature is testable without Playwright MCP (i.e. not behind auth that requires Clerk token injection).

---

## Review checklist

When reviewing existing or newly written e2e tests, flag any:
- `timeout` value > 5 000 without an inline approval comment
- Raw `data-testid` or `data-test-id` string selectors (use `getByTestId`)
- Auth flows that don't use `storageState`
- `waitForResponse` called after the triggering action (race condition)
- Missing POM for a page that has multiple interactions
- `testId` attribute in templates using raw `data-testid` instead of `[testId]` directive
