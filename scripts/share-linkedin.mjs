// scripts/share-linkedin.mjs
// Usage: node scripts/share-linkedin.mjs src/content/blog/my-post.md [...]
// Requires env: LINKEDIN_ACCESS_TOKEN, LINKEDIN_AUTHOR_URN, SITE_URL
// Optional env: BLOG_PATH_PREFIX (default "/blog")

import { readFileSync } from "node:fs";
import { basename } from "node:path";

const TOKEN = process.env.LINKEDIN_ACCESS_TOKEN;
const AUTHOR = process.env.LINKEDIN_AUTHOR_URN; // e.g. urn:li:person:AbC123
const SITE = (process.env.SITE_URL ?? "").replace(/\/$/, "");
const PREFIX = process.env.BLOG_PATH_PREFIX ?? "/blog";

if (!TOKEN || !AUTHOR || !SITE) {
  console.error("Missing LINKEDIN_ACCESS_TOKEN, LINKEDIN_AUTHOR_URN, or SITE_URL");
  process.exit(1);
}

// Minimal frontmatter parse — enough for title/description/draft on simple YAML.
function parseFrontmatter(raw) {
  const m = raw.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  const fm = {};
  if (m) {
    for (const line of m[1].split(/\r?\n/)) {
      const kv = line.match(/^(\w+):\s*(.*)$/);
      if (kv) fm[kv[1]] = kv[2].replace(/^["']|["']$/g, "").trim();
    }
  }
  return fm;
}

function slugFromFile(file) {
  return basename(file).replace(/\.(md|mdx)$/, "");
}

// Cloudflare Pages deploys take a minute or two after push; poll until live.
async function waitForLive(url, { tries = 30, delayMs = 10_000 } = {}) {
  for (let i = 0; i < tries; i++) {
    try {
      const res = await fetch(url, { method: "HEAD", redirect: "follow" });
      if (res.ok) return true;
    } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, delayMs));
  }
  return false;
}

async function shareToLinkedIn({ title, description, url }) {
  const commentary = `New post: ${title}\n\n${url}`;
  const res = await fetch("https://api.linkedin.com/rest/posts", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      "Content-Type": "application/json",
      "X-Restli-Protocol-Version": "2.0.0",
      "LinkedIn-Version": "202506",
    },
    body: JSON.stringify({
      author: AUTHOR,
      commentary,
      visibility: "PUBLIC",
      distribution: {
        feedDistribution: "MAIN_FEED",
        targetEntities: [],
        thirdPartyDistributionChannels: [],
      },
      content: {
        article: {
          source: url,
          title,
          ...(description ? { description } : {}),
        },
      },
      lifecycleState: "PUBLISHED",
      isReshareDisabledByAuthor: false,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`LinkedIn API ${res.status}: ${body}`);
  }
  console.log(`Shared: ${title} -> post id ${res.headers.get("x-restli-id")}`);
}

const files = process.argv.slice(2);
let failed = false;

for (const file of files) {
  try {
    const raw = readFileSync(file, "utf8");
    const fm = parseFrontmatter(raw);

    if (String(fm.draft).toLowerCase() === "true") {
      console.log(`Skipping draft: ${file}`);
      continue;
    }

    const slug = fm.slug || slugFromFile(file);
    const title = fm.title || slug;
    const url = `${SITE}${PREFIX}/${slug}/`;

    console.log(`Waiting for ${url} to go live...`);
    const live = await waitForLive(url);
    if (!live) throw new Error(`${url} never returned 200 — is the deploy stuck?`);

    await shareToLinkedIn({ title, description: fm.description, url });
  } catch (err) {
    console.error(`Failed for ${file}:`, err.message);
    failed = true;
  }
}

process.exit(failed ? 1 : 0);
