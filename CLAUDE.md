# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A marketing/blog site for Battj LLC (engineering management consulting for startups), built with Astro 7 + Tailwind CSS 4, deployed to Cloudflare Pages.

## Commands

Package manager is Bun (`packageManager: bun@1.3.14`).

- `bun run dev` — start local dev server
- `bun run build` — build to `dist/`
- `bun run preview` — preview the production build locally
- `bun astro check` — type-check `.astro` files (uses `@astrojs/check`)

There is no test suite or linter configured in this repo.

## Architecture

- **Content collections**: blog posts are Markdown files in `src/blog/`, loaded via the `glob` loader defined in `src/content.config.ts`. Frontmatter schema is `title`, `description`, `pubDate` (coerced to `Date`), and optional `tags`. Post slugs are the file's `post.id`.
- **Pages** (`src/pages/`):
  - `index.astro` — landing page, composes Header/Hero/Pillars/Approach/Contact/Footer.
  - `blog/index.astro` — blog listing, sorted newest-first.
  - `blog/[slug].astro` — individual post, statically generated from the `blog` collection via `getStaticPaths`.
  - `rss.xml.js` — RSS feed generated with `@astrojs/rss` from the same collection.
- **Layouts** (`src/layouts/`): `BaseLayout.astro` owns the `<html>` shell, SEO/OG/Twitter meta tags, canonical URL, fonts, and favicon; `BlogPostLayout.astro` wraps `BaseLayout` for article pages (adds `type="article"`, `pubDate`, formatted date, prose styling for rendered Markdown content).
- **Components** (`src/components/`): plain `.astro` components (Header, Hero, Footer, Contact, Approach, fourPillars) composed into pages — no client-side framework/islands in use.
- **Styling**: Tailwind CSS 4 via the Vite plugin (`@tailwindcss/vite`), configured in `src/styles/global.css` using `@theme` (no `tailwind.config.js`). Brand palette: `scarlet`, `frozen`, `frosted`, `cerulean`, `indigo` — use these theme colors rather than arbitrary values. Fonts: `DM Sans` (sans) and `Fraunces` (display).
- **Site URL** is set in `astro.config.mjs` (`https://www.battj.llc`) — canonical URLs and the sitemap depend on it.

## Deployment

- Deployed to Cloudflare Pages (see `wrangler.toml`: `pages_build_output_dir = "dist"`, `SKIP_DEPENDENCY_INSTALL = "true"`, pinned `BUN_VERSION`).
- `scripts/configure-pages.sh` pushes build config (build command, output dir, Bun/Node version env vars) to the Cloudflare Pages project via the Cloudflare API. Requires `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` (read from `.env` if present, not committed).
- `.github/workflows/share-linkedin.yml` runs on push to `main` when files under `src/blog/**` are added, and calls `scripts/share-linkedin.mjs` to auto-share newly added (non-draft) blog posts to LinkedIn once the Cloudflare Pages deploy for that post is live. Requires `LINKEDIN_ACCESS_TOKEN` and `LINKEDIN_AUTHOR_URN` secrets.
