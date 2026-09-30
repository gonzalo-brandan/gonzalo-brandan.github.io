# Portfolio Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Chirpy theme with a custom portfolio-first Jekyll theme whose look and motion are close to matthieugivelet.com, keeping all content, live URLs and both deploy pipelines.

**Architecture:** Plain Jekyll 4 with layouts, includes and SCSS in this repo; small single-purpose ES modules (no libraries) started by `assets/js/main.js`. Pure logic (search, TOC, link filtering, theme choice, maths helpers) lives in functions testable with `node --test`; built HTML is checked with Python `unittest` against `_site/`.

**Tech Stack:** Jekyll 4.4, jekyll-seo-tag, jekyll-sitemap, jekyll-feed, jekyll-archives, Dart Sass (via jekyll-sass-converter), vanilla JS ES modules, Inter Tight (OFL, self-hosted), Python 3 `unittest`, Node 22 `node:test`, html-proofer.

**Spec:** `docs/superpowers/specs/2026-09-30-portfolio-redesign-design.md`

## Global Constraints

- All work happens on branch `redesign`. Never push to or merge into `main`; the user approves the merge separately.
- Post URLs stay `/posts/:title/`; `/about/`, `/archives/`, `/tags/` and `/tags/:name/` keep their URLs. `/categories/...` goes away. `/feed.xml` keeps working but is not linked.
- No CSS, JS, text, images or font files are copied from matthieugivelet.com. The font is Inter Tight, self-hosted as woff2 (weights 400, 500, 600, latin subset). No Google Fonts requests.
- No JavaScript libraries. Every JS file is an ES module with one job.
- Colours: background `#FFFFFF`, text `#000000`, borders black at 10%, accent `#FFFB24`. Dark mode inverts background and text and keeps the accent.
- Labels are written in square brackets, e.g. `[ Berlin ]`.
- Every page shows all its content without JavaScript. Reveal starting states apply only when `<html>` has the `js` class.
- All motion is off under `prefers-reduced-motion: reduce`.
- Loader: at most once per browser session; skipped when storage is unavailable.
- No horizontal page scroll at 320px width.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **`main.js` fails to load or loads very late** (bad network, a syntax error in one module): content must not stay hidden and the loader must not cover the page forever. → Inline fail-safe in `head.html` removes `js`/`is-loading` after 4 s unless `main.js` set `js-ready`; `main.js` wraps each module so one failure doesn't stop the rest, and reveals everything if reveal fails. Pinned by a build test in Task 1 and a browser check in Task 8.
2. **Links that must not get the fade-out transition:** new-tab/modified clicks, `target="_blank"`, downloads, external sites, `mailto:`, same-page `#anchors`, and file links like `/feed.xml`. → `shouldAnimateNavigation` node tests in Task 8.
3. **Returning with the Back button after a transition** (back/forward cache restores the faded-out page). → `pageshow` handler in Task 8, browser check in Task 8.
4. **Pages shorter than the window:** the About photo scale must not divide by zero; elements at the very bottom (footer) must still reveal. → `scaleForProgress`/`scrollProgress` node tests in Task 6; reveal uses `threshold: 0` with no negative root margin (Task 8).
5. **Search input edge cases:** empty or whitespace-only query, accented words, regex characters like `(`, a failed `search.json` request, and fast typing overtaking a slow first load. → `searchPosts` node tests and stale-result guard in Task 7.

## How to run the checks

- Build + all automated tests: `bash tools/check.sh`
- Same plus html-proofer (as CI runs it): `bash tools/check.sh --proof`
- Local preview: `bundle exec jekyll serve --livereload` → <http://127.0.0.1:4000/> (restart after editing `_config.yml`)

---

### Task 1: Replace Chirpy with a minimal custom theme

Deliverable: the site builds without Chirpy, every live URL (except categories) still exists, pages use the new shell, fonts are self-hosted, and there is a one-command test runner.

**Files:**
- Modify: `Gemfile`, `_config.yml` (full rewrite), `.gitignore` (no change needed; `_site` already ignored)
- Create: `tools/check.sh`, `test/helpers.py`, `test/test_foundation.py`, `test/fixtures/live-urls.txt`
- Create: `_layouts/default.html`, `_layouts/page.html`, `_layouts/post.html`, `_layouts/home.html`, `_layouts/archive.html`, `_layouts/tag.html`
- Create: `_includes/head.html`
- Create: `_sass/_tokens.scss`, `_sass/_base.scss`, `_sass/_layout.scss`, `_sass/_components.scss`, `_sass/_post.scss`, `_sass/_syntax.scss`, `_sass/_animations.scss`, `assets/css/main.scss`
- Create: `assets/js/main.js`, `assets/fonts/inter-tight-latin-{400,500,600}-normal.woff2`, `assets/fonts/OFL.txt`
- Create: `about.md`, `archives.md`, `tags.html` (moved from `_tabs/`)
- Delete: `_tabs/` (all four files), `_sass/abstracts/`, `assets/css/jekyll-theme-chirpy.scss`, `_data/contact.yml`, `_data/share.yml`, `_data/origin/`

**Interfaces:**
- Produces: layouts `default`, `page`, `post`, `home`, `archive`, `tag`; `test/helpers.py` functions `built_file(path) -> Path`, `read_page(path) -> str`, `elements(html) -> list[(tag, attrs)]`, `find(html, tag=None, cls=None, **attrs) -> list[(tag, attrs)]` (attribute names use `_` for `-`; valueless attributes match `""`); `main.js` helper `run(name, init, fallback?)`; CSS tokens `--color-bg`, `--color-text`, `--color-muted`, `--color-border`, `--color-surface`, `--color-accent`, `--color-accent-text`, `--font-primary`, `--font-mono`, `--fs-xxs|xs|s|m|l|xl`, `--gutter`, `--header-h`, `--radius`, `--ease-out`, `--ease-in-out`, `--dur-reveal`; classes `.label`, `.rule`, `.skip-link`, `.page-head`, `.page-title`, `.prose`.
- Config keys later tasks read: `site.author`, `site.location`, `site.location_country`, `site.social.email`, `site.linkedin_username`, `site.github_username`, `site.avatar`, `site.comments.giscus.*`.

- [ ] **Step 1: Write the test helpers**

Create `test/helpers.py`:

```python
"""Helpers for checking the built site in _site/."""
import pathlib
from html.parser import HTMLParser

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = ROOT / "_site"


def built_file(url_path):
    """Map a site URL path such as '/posts/x/' to its file in _site."""
    rel = url_path.lstrip("/")
    if rel == "" or rel.endswith("/"):
        rel += "index.html"
    return SITE / rel


def read_page(url_path):
    return built_file(url_path).read_text(encoding="utf-8")


class _Collector(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.elements = []

    def handle_starttag(self, tag, attrs):
        self.elements.append((tag, {k: (v or "") for k, v in attrs}))


def elements(html):
    collector = _Collector()
    collector.feed(html)
    return collector.elements


def find(html, tag=None, cls=None, **attrs):
    """Start tags matching a tag name, a class token and exact attribute values.

    Attribute names use '_' for '-' (data_reveal='line'). Valueless attributes equal ''.
    """
    matches = []
    for name, found in elements(html):
        if tag and name != tag:
            continue
        if cls and cls not in found.get("class", "").split():
            continue
        if any(found.get(key.replace("_", "-")) != value for key, value in attrs.items()):
            continue
        matches.append((name, found))
    return matches


def dated_post_count():
    return len(list((ROOT / "_posts").glob("20*.md")))


def featured_post_count():
    return sum(
        1 for path in (ROOT / "_posts").glob("20*.md")
        if "\nfeatured: true\n" in path.read_text(encoding="utf-8")
    )
```

- [ ] **Step 2: Save the live URL list**

Create `test/fixtures/live-urls.txt` (paths from https://gonzalobrandan.com/sitemap.xml on 2026-09-30, categories removed on purpose):

```
# Every URL the live site had before the redesign, minus /categories/.
/
/about/
/archives/
/tags/
/posts/configure-a-basic-wlan-on-the-wlc/
/posts/Configure-Secure-DMVPN-Tunnels/
/posts/Implement-IPsec-Site-to-Site-VPNs-IPSec-post/
/posts/Creating-a-redundant-network/
/posts/From-fundamentals-to-enterprise-complexity/
/tags/wlan/
/tags/cisco/
/tags/tutorial/
/tags/ipsec/
/tags/dmvpn/
/tags/security/
/tags/redundancy/
/tags/vlan/
/tags/nat/
/tags/hsrp/
/tags/bgp/
/tags/roas/
/tags/dhcp/
/tags/project/
/tags/ospf/
/tags/pat/
/feed.xml
```

- [ ] **Step 3: Write the failing foundation tests**

Create `test/test_foundation.py`:

```python
import unittest

from helpers import ROOT, SITE, built_file, find, read_page

FIXTURE = ROOT / "test" / "fixtures" / "live-urls.txt"
SHELL_PAGES = [
    "/", "/about/", "/archives/", "/tags/", "/tags/cisco/",
    "/posts/Creating-a-redundant-network/",
]


class FoundationTest(unittest.TestCase):
    def test_every_live_url_still_builds(self):
        paths = [
            line.strip() for line in FIXTURE.read_text().splitlines()
            if line.strip() and not line.startswith("#")
        ]
        missing = [path for path in paths if not built_file(path).is_file()]
        self.assertEqual(missing, [], f"Live URLs missing from the build: {missing}")

    def test_categories_pages_are_gone(self):
        self.assertFalse(built_file("/categories/").exists())

    def test_chirpy_is_gone(self):
        self.assertFalse((SITE / "assets/css/jekyll-theme-chirpy.css").exists())
        self.assertNotIn("chirpy", read_page("/").lower())

    def test_pages_use_the_new_shell(self):
        for path in SHELL_PAGES:
            with self.subTest(path=path):
                html = read_page(path)
                self.assertTrue(find(html, "link", rel="stylesheet", href="/assets/css/main.css"))
                self.assertTrue(find(html, "script", type="module", src="/assets/js/main.js"))
                self.assertTrue(find(html, "main", id="main"))

    def test_head_has_js_failsafe(self):
        html = read_page("/")
        self.assertIn("classList.add('js')", html)
        self.assertIn("js-ready", html)
        self.assertIn("remove('js', 'is-loading')", html)

    def test_fonts_are_self_hosted(self):
        for weight in (400, 500, 600):
            self.assertTrue((SITE / f"assets/fonts/inter-tight-latin-{weight}-normal.woff2").is_file())
        css = (SITE / "assets/css/main.css").read_text()
        self.assertIn("Inter Tight", css)
        self.assertNotIn("fonts.googleapis.com", css + read_page("/"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 4: Write the check runner**

Create `tools/check.sh`:

```bash
#!/usr/bin/env bash
#
# Build the site and run every automated check.
# Usage: bash tools/check.sh [--proof]   (--proof also runs html-proofer like CI)

set -euo pipefail
cd "$(dirname "$0")/.."

bundle exec jekyll build --quiet
python3 -m unittest discover -s test -p 'test_*.py'

shopt -s nullglob
js_tests=(test/js/*.test.mjs)
if ((${#js_tests[@]})); then
  node --test "${js_tests[@]}"
fi

if [[ "${1:-}" == "--proof" ]]; then
  bundle exec htmlproofer _site \
    --disable-external \
    --ignore-urls "/^http:\/\/127.0.0.1/,/^http:\/\/0.0.0.0/,/^http:\/\/localhost/"
fi
```

- [ ] **Step 5: Run the tests to see them fail on the Chirpy build**

Run: `bash tools/check.sh`
Expected: FAIL — `test_pages_use_the_new_shell` (no `main.css`), `test_categories_pages_are_gone`, `test_chirpy_is_gone`, `test_head_has_js_failsafe`, `test_fonts_are_self_hosted`.

- [ ] **Step 6: Swap the gems**

Replace `Gemfile` with:

```ruby
# frozen_string_literal: true

source "https://rubygems.org"

gem "jekyll", "~> 4.4"

group :jekyll_plugins do
  gem "jekyll-seo-tag", "~> 2.8"
  gem "jekyll-sitemap", "~> 1.4"
  gem "jekyll-feed", "~> 0.17"
  gem "jekyll-archives", "~> 2.3"
end

gem "html-proofer", "~> 5.0", group: :test

platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end

gem "wdm", "~> 0.2.0", :platforms => [:mingw, :x64_mingw, :mswin]
```

Run: `bundle install`
Expected: "Bundle complete!" and `Gemfile.lock` no longer lists `jekyll-theme-chirpy`.

- [ ] **Step 7: Rewrite `_config.yml`**

Replace `_config.yml` with:

```yaml
# Site settings. Restart `jekyll serve` after editing this file.

title: Gonzalo Brandan
tagline: I like solving infrastructure problems.
description: >-
  Articles and lab notes on Cisco networking, wireless, routing, switching, and my progress toward the CCNP certification.
url: "https://gonzalo-brandan.github.io" # the AWS deploy overrides this with _config.aws.yml
baseurl: ""
lang: en

author: Gonzalo Brandan
location: Berlin
location_country: Germany
avatar: /assets/static/Image.jpeg
linkedin_username: gonzalo-brandan
github_username: gonzalo-brandan

social:
  name: Gonzalo Brandan
  email: gonzalobrandan@outlook.de
  links:
    - https://github.com/gonzalo-brandan
    - https://www.linkedin.com/in/gonzalo-brandan/

comments:
  giscus:
    repo: gonzalo-brandan/gonzalo-brandan.github.io
    repo_id: R_kgDOQfVneg
    category: Announcements
    category_id: DIC_kwDOQfVnes4DEwP7
    mapping: pathname

plugins:
  - jekyll-seo-tag
  - jekyll-sitemap
  - jekyll-feed
  - jekyll-archives

kramdown:
  footnote_backlink: "&#8617;&#xfe0e;"
  syntax_highlighter: rouge
  syntax_highlighter_opts:
    css_class: highlight
    span:
      line_numbers: false

defaults:
  - scope:
      path: ""
      type: posts
    values:
      layout: post
      comments: true
      toc: true
      # Do not change: live links, the CV and LinkedIn point at these URLs.
      permalink: /posts/:title/
  - scope:
      path: _drafts
    values:
      comments: false
  # No default layout for pages: it would also wrap assets/css/main.scss.
  # Every page sets its layout in its own front matter.

jekyll-archives:
  enabled: [tags]
  layouts:
    tag: tag
  permalinks:
    tag: /tags/:name/

sass:
  style: compressed

exclude:
  - "*.gem"
  - "*.gemspec"
  - docs
  - tools
  - infra
  - scripts
  - test
  - README.md
  - LICENSE
  - how_it_works.txt
  - "package*.json"
  - Gemfile
  - Gemfile.lock
  - vendor
```

- [ ] **Step 8: Remove Chirpy files and move the tab pages**

```bash
git rm -r -q _tabs _sass/abstracts assets/css/jekyll-theme-chirpy.scss _data/contact.yml _data/share.yml _data/origin
```

Create `about.md` with the current About text (unchanged wording; Task 6 restructures it):

```markdown
---
layout: page
title: About
permalink: /about/
---

Hi, I'm Gonzalo. I like solving infrastructure problems, and I'm most at home where the physical and the logical meet: the rack, the cabling, the switch config and the routing table that ties it all together.

## How I got here

Before IT, I managed customer service and guest relations at a 1,300-guest hotel in Berlin for 18 months. I handled the escalated cases, from overbookings to payment problems, and built the escalation process the team still uses. It taught me that a problem only goes away when you fix what caused it.

In 2025 I made the move into IT. I completed CCNA and CCNP Enterprise training, where most of the time was spent in the lab, and I'm studying Computer Engineering part-time at the Universitat Oberta de Catalunya alongside it.

## What I build

- **Cisco labs:** multi-site enterprise networks with redundancy at every layer (BGP, HSRP, port-channels, spanning tree), VLAN segmentation, multi-area OSPF, DHCP relay, NAT and site-to-site and DMVPN tunnels secured with IPsec.
- **A small data center at home:** a spine-leaf fabric of Cisco Catalyst switches with fiber and copper links, a structured and labeled patch panel, out-of-band access through a PiKVM and a serial console server, a UPS with safe shutdown, and runbooks for the failures I expect to hit. It's still being built, and I'll write about it here as it comes together.
- **Automation and cloud:** I'm starting to manage my lab configs with Ansible from a RHEL machine, and this blog runs on AWS (S3 and CloudFront, set up with Terraform).

## Why this blog

I write up everything I build: the problem, the design, the configuration, the tests and what broke along the way. It's part portfolio and part learning log. If you want to see how I think about networks, the posts are the best place to start.

I speak Spanish, English and German. If you want to talk about networking, data centers or an opportunity, you can reach me on [LinkedIn](https://www.linkedin.com/in/gonzalo-brandan/) or by [email](mailto:gonzalobrandan@outlook.de).
```

Before writing it, run `git show main:_tabs/about.md` and confirm the body text matches the above exactly; if it differs, keep the text from `main`.

Create `archives.md`:

```markdown
---
layout: archive
title: Archive
heading: Lab notes
permalink: /archives/
intro: Every lab and write-up, newest first.
---
```

Create `tags.html` (HTML rather than Markdown, so Kramdown leaves the markup alone):

```html
---
layout: page
title: Tags
permalink: /tags/
plain: true
---
{% assign tags = site.tags | sort %}
<ul class="tag-index">
  {% for tag in tags %}
    {% assign slug = tag[0] | slugify %}
    <li><a href="{{ '/tags/' | append: slug | append: '/' | relative_url }}">{{ tag[0] }} <sup>({{ tag[1].size }})</sup></a></li>
  {% endfor %}
</ul>
```

- [ ] **Step 9: Download the font**

```bash
mkdir -p assets/fonts
for w in 400 500 600; do
  curl -fsSL -o "assets/fonts/inter-tight-latin-$w-normal.woff2" \
    "https://cdn.jsdelivr.net/npm/@fontsource/inter-tight@5/files/inter-tight-latin-$w-normal.woff2"
done
curl -fsSL -o assets/fonts/OFL.txt https://raw.githubusercontent.com/google/fonts/main/ofl/intertight/OFL.txt
file assets/fonts/*.woff2
```

Expected: three files reported as `Web Open Font Format (Version 2)`.

- [ ] **Step 10: Write the head include and the layouts**

Create `_includes/head.html`:

```html
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script>
  (function () {
    var d = document.documentElement;
    d.classList.add('js');
    try {
      var t = localStorage.getItem('theme');
      if (t === 'light' || t === 'dark') d.setAttribute('data-theme', t);
    } catch (e) {}
    try {
      var s = window.sessionStorage;
      if (!window.matchMedia('(prefers-reduced-motion: reduce)').matches && s.getItem('loader-seen') !== '1') {
        s.setItem('loader-seen', '1');
        d.classList.add('is-loading');
      }
    } catch (e) {}
    // Fail-safe: if main.js never starts, show the page without animations.
    setTimeout(function () {
      if (!d.classList.contains('js-ready')) d.classList.remove('js', 'is-loading');
    }, 4000);
  })();
</script>
{% seo %}
<meta name="theme-color" content="#ffffff" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#0b0b0b" media="(prefers-color-scheme: dark)">
<link rel="icon" href="{{ '/assets/img/favicons/favicon.ico' | relative_url }}" sizes="any">
<link rel="icon" href="{{ '/assets/img/favicons/favicon.svg' | relative_url }}" type="image/svg+xml">
<link rel="apple-touch-icon" href="{{ '/assets/img/favicons/apple-touch-icon.png' | relative_url }}">
<link rel="preload" href="{{ '/assets/fonts/inter-tight-latin-400-normal.woff2' | relative_url }}" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="{{ '/assets/css/main.css' | relative_url }}">
<script type="module" src="{{ '/assets/js/main.js' | relative_url }}"></script>
```

Create `_layouts/default.html` (Tasks 2 and 8 add the header, menu, footer and loader includes):

```html
<!doctype html>
<html lang="{{ site.lang | default: 'en' }}">
<head>
{% include head.html %}
</head>
<body class="layout-{{ page.layout | default: 'none' }}">
  <main id="main" class="site-main" tabindex="-1">
    {{ content }}
  </main>
</body>
</html>
```

Create `_layouts/page.html`:

```html
---
layout: default
---
<section class="page-head">
  <p class="label" data-reveal="line">[ {{ page.label | default: page.title }} ]</p>
  <h1 class="page-title" data-reveal="line">{{ page.heading | default: page.title }}</h1>
</section>
<div class="page-body{% unless page.plain %} prose{% endunless %}">
  {{ content }}
</div>
```

Create `_layouts/post.html` (Task 3 replaces it with the full version):

```html
---
layout: default
---
<article class="post">
  <header class="page-head">
    <h1 class="page-title">{{ page.title }}</h1>
  </header>
  <div class="prose">{{ content }}</div>
</article>
```

Create `_layouts/home.html` (Task 4 replaces it):

```html
---
layout: default
---
<section class="page-head">
  <h1 class="page-title">{{ site.tagline }}</h1>
</section>
```

Create `_layouts/archive.html` (Task 5 replaces it):

```html
---
layout: default
---
<section class="page-head">
  <h1 class="page-title">{{ page.heading | default: page.title }}</h1>
</section>
<ul>
  {% for post in site.posts %}<li><a href="{{ post.url | relative_url }}">{{ post.title }}</a></li>{% endfor %}
</ul>
```

Create `_layouts/tag.html` (Task 5 replaces it):

```html
---
layout: default
---
<section class="page-head">
  <h1 class="page-title">{{ page.title }}</h1>
</section>
<ul>
  {% for post in page.posts %}<li><a href="{{ post.url | relative_url }}">{{ post.title }}</a></li>{% endfor %}
</ul>
```

- [ ] **Step 11: Write the base styles**

Create `_sass/_tokens.scss`:

```scss
@mixin light-tokens {
  --color-bg: #ffffff;
  --color-text: #000000;
  --color-muted: rgba(0, 0, 0, 0.55);
  --color-border: rgba(0, 0, 0, 0.1);
  --color-surface: #f3f3f1;
  --color-accent: #fffb24;
  --color-accent-text: #000000;
  --syn-comment: #6b6b6b;
  --syn-keyword: #7a3e9d;
  --syn-string: #2f7d32;
  --syn-number: #b35c00;
  --syn-name: #1f5fa8;
  color-scheme: light;
}

@mixin dark-tokens {
  --color-bg: #0b0b0b;
  --color-text: #f5f5f3;
  --color-muted: rgba(245, 245, 243, 0.6);
  --color-border: rgba(245, 245, 243, 0.14);
  --color-surface: #171717;
  --color-accent: #fffb24;
  --color-accent-text: #000000;
  --syn-comment: #9a9a9a;
  --syn-keyword: #d3a6f0;
  --syn-string: #9bd49f;
  --syn-number: #f2b36b;
  --syn-name: #8fbef5;
  color-scheme: dark;
}

:root {
  @include light-tokens;
  --font-primary: "Inter Tight", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  --font-mono: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace;
  --fs-xxs: clamp(0.72rem, 0.8vw, 0.85rem);
  --fs-xs: clamp(0.8rem, 1vw, 1rem);
  --fs-s: clamp(0.95rem, 1.25vw, 1.3rem);
  --fs-m: clamp(1.1rem, 1.6vw, 1.8rem);
  --fs-l: clamp(1.7rem, 3.2vw, 3.6rem);
  --fs-xl: clamp(2rem, 10.5vw, 10.5rem);
  --gutter: clamp(16px, 1.6vw, 28px);
  --header-h: 64px;
  --radius: 4px;
  --ease-out: cubic-bezier(0.2, 0.7, 0.2, 1);
  --ease-in-out: cubic-bezier(0.7, 0, 0.3, 1);
  --dur-reveal: 1s;
}

:root[data-theme="dark"] {
  @include dark-tokens;
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    @include dark-tokens;
  }
}
```

Create `_sass/_base.scss`:

```scss
@font-face {
  font-family: "Inter Tight";
  src: url("../fonts/inter-tight-latin-400-normal.woff2") format("woff2");
  font-weight: 400;
  font-style: normal;
  font-display: swap;
}

@font-face {
  font-family: "Inter Tight";
  src: url("../fonts/inter-tight-latin-500-normal.woff2") format("woff2");
  font-weight: 500;
  font-style: normal;
  font-display: swap;
}

@font-face {
  font-family: "Inter Tight";
  src: url("../fonts/inter-tight-latin-600-normal.woff2") format("woff2");
  font-weight: 600;
  font-style: normal;
  font-display: swap;
}

*,
*::before,
*::after {
  box-sizing: border-box;
}

html {
  -webkit-text-size-adjust: 100%;
  scroll-behavior: smooth;
}

body {
  margin: 0;
  background: var(--color-bg);
  color: var(--color-text);
  font-family: var(--font-primary);
  font-size: var(--fs-s);
  line-height: 1.45;
  letter-spacing: -0.01em;
  -webkit-font-smoothing: antialiased;
  transition: background-color 0.4s, color 0.4s;
}

img,
svg,
video {
  display: block;
  max-width: 100%;
  height: auto;
}

a {
  color: inherit;
  text-decoration: underline;
  text-decoration-thickness: 1px;
  text-underline-offset: 0.18em;
}

h1,
h2,
h3,
h4,
h5,
h6 {
  margin: 0;
  font-weight: 500;
  line-height: 1;
  letter-spacing: -0.04em;
}

p,
figure {
  margin: 0;
}

ul,
ol {
  margin: 0;
  padding: 0;
}

button {
  font: inherit;
  color: inherit;
  background: none;
  border: 0;
  padding: 0;
  cursor: pointer;
}

sup {
  font-size: 0.6em;
  line-height: 0;
  vertical-align: super;
}

::selection {
  background: var(--color-accent);
  color: var(--color-accent-text);
}

:focus-visible {
  outline: 2px solid currentColor;
  outline-offset: 3px;
}

.label {
  font-size: var(--fs-xxs);
  color: var(--color-muted);
  letter-spacing: 0;
  white-space: nowrap;
}

.rule {
  border: 0;
  height: 1px;
  margin: 0;
  background: var(--color-border);
}

.skip-link {
  position: absolute;
  left: var(--gutter);
  top: -100px;
  z-index: 100;
  padding: 0.6em 1em;
  background: var(--color-accent);
  color: var(--color-accent-text);
}

.skip-link:focus {
  top: var(--gutter);
}
```

Create `_sass/_layout.scss`:

```scss
.site-main {
  min-height: 70vh;
  padding: 0 var(--gutter);
  outline: none;
}

.page-head {
  display: grid;
  gap: 1.5rem;
  padding: 12vh 0 6vh;
}

.page-title {
  font-size: var(--fs-xl);
  line-height: 0.92;
  letter-spacing: -0.05em;
  overflow-wrap: break-word;
}

.page-head__aside {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: flex-end;
  gap: 1rem 2rem;
  font-size: var(--fs-m);
}

.page-head__intro {
  max-width: 28ch;
}

.page-body {
  padding-bottom: 8vh;
}
```

Create `_sass/_post.scss` (prose styles are needed as soon as posts render; Task 3 adds the post layout rules):

```scss
.prose {
  min-width: 0;
  max-width: 72ch;
  font-size: var(--fs-s);
  line-height: 1.6;
  overflow-wrap: break-word;
}

.prose > * + * {
  margin-top: 1.1em;
}

.prose h2,
.prose h3,
.prose h4 {
  margin-top: 2.2em;
  line-height: 1.1;
  scroll-margin-top: calc(var(--header-h) + 1rem);
}

.prose h2 {
  font-size: var(--fs-l);
}

.prose h3 {
  font-size: var(--fs-m);
}

.prose h4 {
  font-size: var(--fs-s);
  letter-spacing: -0.01em;
}

.prose ul,
.prose ol {
  padding-left: 1.3em;
}

.prose li + li {
  margin-top: 0.35em;
}

.prose strong {
  font-weight: 600;
}

.prose img {
  margin: 1.5em 0;
  border-radius: var(--radius);
}

.prose a:hover {
  background: var(--color-accent);
  color: var(--color-accent-text);
}

.prose code {
  padding: 0.1em 0.35em;
  border-radius: 3px;
  background: var(--color-surface);
  font-family: var(--font-mono);
  font-size: 0.88em;
}

.prose pre {
  overflow-x: auto;
  margin: 0;
  padding: 1.1em 1.3em;
  border-radius: var(--radius);
  background: var(--color-surface);
  font-size: var(--fs-xs);
  line-height: 1.55;
}

.prose pre code {
  padding: 0;
  background: none;
  font-size: inherit;
}

.prose table {
  display: block;
  overflow-x: auto;
  max-width: 100%;
  border-collapse: collapse;
  font-size: var(--fs-xs);
}

.prose th,
.prose td {
  padding: 0.6em 0.8em;
  border-bottom: 1px solid var(--color-border);
  text-align: left;
  vertical-align: top;
}

.prose th {
  font-weight: 600;
}

.prose blockquote {
  margin: 1.5em 0;
  padding-left: 1.2em;
  border-left: 2px solid var(--color-accent);
  color: var(--color-muted);
}

.prose hr {
  height: 1px;
  margin: 3em 0;
  border: 0;
  background: var(--color-border);
}
```

Create `_sass/_syntax.scss`:

```scss
.highlight {
  .c, .c1, .cm, .cs, .cp { color: var(--syn-comment); font-style: italic; }
  .k, .kd, .kn, .kr, .kt, .kc { color: var(--syn-keyword); }
  .s, .s1, .s2, .sb, .sd, .se, .sh, .si, .sx { color: var(--syn-string); }
  .m, .mi, .mf, .mh, .mo, .il { color: var(--syn-number); }
  .nb, .nf, .na, .nc, .nn, .nt, .nv { color: var(--syn-name); }
  .err { color: inherit; background: none; }
}
```

Create empty placeholders that later tasks fill: `_sass/_components.scss` and `_sass/_animations.scss`, each containing only a one-line comment:

```scss
// Filled in by later tasks.
```

Create `assets/css/main.scss`:

```scss
---
---

@use "tokens";
@use "base";
@use "layout";
@use "components";
@use "post";
@use "syntax";
@use "animations";
```

- [ ] **Step 12: Write the JS entry point**

Create `assets/js/main.js`:

```js
// Starts each page feature. One failing module must not stop the others.

const html = document.documentElement;
html.classList.add('js-ready');

function run(name, init, fallback) {
  try {
    init();
  } catch (error) {
    console.error(`[site] ${name} failed`, error);
    fallback?.();
  }
}
```

(Later tasks add `import` lines at the top and `run(...)` calls at the bottom. `run` is intentionally unused until Task 2.)

- [ ] **Step 13: Run the checks**

Run: `bash tools/check.sh`
Expected: PASS for all `FoundationTest` tests. If `test_every_live_url_still_builds` lists `/tags/...` URLs, check that the tag slugs match the live ones (jekyll-archives slugifies the same way Chirpy did).

- [ ] **Step 14: Commit**

```bash
git add -A Gemfile Gemfile.lock _config.yml tools/check.sh test _layouts _includes _sass assets/css assets/js assets/fonts about.md archives.md tags.html
git commit -m "$(cat <<'EOF'
Replace Chirpy with a minimal custom theme

Adds the build/test runner, self-hosted Inter Tight, base tokens and
layouts, and keeps every live URL except the categories pages.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Header, menu, footer and light/dark switch

Deliverable: every page has the skip link, top bar with live counts, full-screen phone menu, footer with contact details, and a working theme switch.

**Files:**
- Create: `_includes/header.html`, `_includes/menu.html`, `_includes/footer.html`, `assets/js/menu.js`, `assets/js/theme.js`, `test/test_shell.py`, `test/js/theme.test.mjs`
- Modify: `_layouts/default.html`, `_sass/_layout.scss` (append), `_sass/_components.scss` (replace placeholder), `assets/js/main.js`

**Interfaces:**
- Consumes: `run` from `main.js`; `find`, `elements`, `read_page`, `dated_post_count`, `featured_post_count` from `test/helpers.py`; config keys from Task 1.
- Produces: `initMenu(root = document)` in `menu.js`; `initTheme(root = document)`, `nextTheme(current, systemPrefersDark) -> 'light' | 'dark'`, `THEME_KEY = 'theme'` in `theme.js`; element hooks `[data-menu]`, `[data-menu-open]`, `[data-menu-close]`, `[data-theme-toggle]`; footer `id="contact"`.

- [ ] **Step 1: Write the failing tests**

Create `test/test_shell.py`:

```python
import unittest

from helpers import dated_post_count, elements, featured_post_count, find, read_page


class ShellTest(unittest.TestCase):
    def setUp(self):
        self.html = read_page("/about/")

    def test_skip_link_is_the_first_link(self):
        first_link = next(attrs for tag, attrs in elements(self.html) if tag == "a")
        self.assertEqual(first_link.get("href"), "#main")

    def test_nav_shows_live_counts(self):
        self.assertIn(f"Work <sup>({featured_post_count()})</sup>", self.html)
        self.assertIn(f"Archive <sup>({dated_post_count()})</sup>", self.html)

    def test_current_page_is_marked(self):
        self.assertTrue(find(self.html, "a", href="/about/", aria_current="page"))

    def test_menu_is_a_hidden_dialog_controlled_by_a_button(self):
        menus = find(self.html, "div", id="menu", role="dialog", aria_modal="true")
        self.assertEqual(len(menus), 1)
        self.assertIn("hidden", menus[0][1])
        self.assertTrue(find(self.html, "button", aria_controls="menu", aria_expanded="false"))

    def test_theme_switch_in_header_and_menu(self):
        self.assertEqual(len(find(self.html, "button", data_theme_toggle="")), 2)

    def test_footer_has_contact_details(self):
        self.assertTrue(find(self.html, "footer", id="contact"))
        self.assertTrue(find(self.html, "a", href="mailto:gonzalobrandan@outlook.de"))
        self.assertTrue(find(self.html, "a", href="https://www.linkedin.com/in/gonzalo-brandan/"))


if __name__ == "__main__":
    unittest.main()
```

Create `test/js/theme.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { nextTheme } from '../../assets/js/theme.js';

test('an explicit choice flips to the other theme', () => {
  assert.equal(nextTheme('dark', false), 'light');
  assert.equal(nextTheme('light', true), 'dark');
});

test('with no saved choice, switches away from the system theme', () => {
  assert.equal(nextTheme(undefined, true), 'light');
  assert.equal(nextTheme(undefined, false), 'dark');
  assert.equal(nextTheme('', true), 'light');
});

test('ignores unexpected saved values', () => {
  assert.equal(nextTheme('purple', true), 'light');
});
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `bash tools/check.sh`
Expected: FAIL — `ShellTest` failures, and the node test fails with `Cannot find module .../assets/js/theme.js`.

- [ ] **Step 3: Write the includes**

Create `_includes/header.html`:

```html
{% assign featured = site.posts | where: "featured", true %}
<header class="site-header">
  <a class="site-header__name" href="{{ '/' | relative_url }}">{{ site.author }}</a>
  <nav class="site-nav" aria-label="Main">
    <a href="{{ '/work/' | relative_url }}"{% if page.url == '/work/' %} aria-current="page"{% endif %}>Work <sup>({{ featured.size }})</sup></a>
    <a href="{{ '/archives/' | relative_url }}"{% if page.url == '/archives/' %} aria-current="page"{% endif %}>Archive <sup>({{ site.posts.size }})</sup></a>
    <a href="{{ '/about/' | relative_url }}"{% if page.url == '/about/' %} aria-current="page"{% endif %}>About</a>
    <a href="{{ '/search/' | relative_url }}"{% if page.url == '/search/' %} aria-current="page"{% endif %}>Search</a>
    <a href="#contact">Contact</a>
    <button class="theme-toggle" type="button" aria-label="Switch colour theme" data-theme-toggle>
      <span class="theme-toggle__dot" aria-hidden="true"></span>
    </button>
  </nav>
  <button class="menu-button" type="button" aria-expanded="false" aria-controls="menu" data-menu-open>Menu</button>
</header>
```

Create `_includes/menu.html`:

```html
{% assign featured = site.posts | where: "featured", true %}
<div class="menu" id="menu" role="dialog" aria-modal="true" aria-label="Navigation" hidden data-menu>
  <div class="menu__top">
    <span class="label">[ Navigation ]</span>
    <button class="menu__close" type="button" data-menu-close>Close</button>
  </div>
  <nav class="menu__links" aria-label="Mobile">
    <a href="{{ '/' | relative_url }}">Home</a>
    <a href="{{ '/work/' | relative_url }}">Work <sup>({{ featured.size }})</sup></a>
    <a href="{{ '/archives/' | relative_url }}">Archive <sup>({{ site.posts.size }})</sup></a>
    <a href="{{ '/about/' | relative_url }}">About</a>
    <a href="{{ '/search/' | relative_url }}">Search</a>
    <a href="#contact" data-menu-close>Contact</a>
  </nav>
  <div class="menu__bottom">
    <span class="label">[ {{ site.location }} ]</span>
    <button class="theme-toggle" type="button" aria-label="Switch colour theme" data-theme-toggle>
      <span class="theme-toggle__dot" aria-hidden="true"></span>
    </button>
  </div>
</div>
```

Create `_includes/footer.html`:

```html
<footer class="site-footer" id="contact">
  <hr class="rule" data-reveal="rule">
  <div class="site-footer__grid">
    <div class="site-footer__open">
      <p class="label" data-reveal="line">[ Open ]</p>
      <p class="site-footer__invite" data-reveal="line">
        I'm looking for my first role in IT, ideally close to the hardware: networking, data center operations or IT support. Feel free to <a href="mailto:{{ site.social.email }}">say hello</a>.
      </p>
    </div>
    <div class="site-footer__contact">
      <p class="label" data-reveal="line">[ Contact ]</p>
      <ul class="site-footer__links">
        <li data-reveal="line">Email: <a href="mailto:{{ site.social.email }}">{{ site.social.email }}</a></li>
        <li data-reveal="line">LinkedIn: <a href="https://www.linkedin.com/in/{{ site.linkedin_username }}/">{{ site.linkedin_username }}</a></li>
        <li data-reveal="line">GitHub: <a href="https://github.com/{{ site.github_username }}">{{ site.github_username }}</a></li>
      </ul>
    </div>
    <p class="site-footer__copy">© {{ 'now' | date: '%Y' }} {{ site.author }}</p>
  </div>
</footer>
```

Replace `_layouts/default.html` with:

```html
<!doctype html>
<html lang="{{ site.lang | default: 'en' }}">
<head>
{% include head.html %}
</head>
<body class="layout-{{ page.layout | default: 'none' }}">
  <a class="skip-link" href="#main">Skip to content</a>
  {% include header.html %}
  {% include menu.html %}
  <main id="main" class="site-main" tabindex="-1">
    {{ content }}
  </main>
  {% include footer.html %}
</body>
</html>
```

- [ ] **Step 4: Write the JS modules**

Create `assets/js/theme.js`:

```js
// Light/dark switch. A saved choice ('light' | 'dark') overrides the system setting.
// The inline script in head.html applies the saved choice before first paint.

export const THEME_KEY = 'theme';

export function nextTheme(current, systemPrefersDark) {
  const effective = current === 'light' || current === 'dark'
    ? current
    : (systemPrefersDark ? 'dark' : 'light');
  return effective === 'dark' ? 'light' : 'dark';
}

export function initTheme(root = document) {
  const html = document.documentElement;
  const system = window.matchMedia('(prefers-color-scheme: dark)');
  const buttons = root.querySelectorAll('[data-theme-toggle]');
  const effective = () => html.dataset.theme || (system.matches ? 'dark' : 'light');

  const updateLabels = () => {
    const label = effective() === 'dark' ? 'Switch to light theme' : 'Switch to dark theme';
    buttons.forEach((button) => button.setAttribute('aria-label', label));
  };

  // Keeps the giscus comments iframe in the same theme as the page.
  const syncGiscus = () => {
    const frame = document.querySelector('iframe.giscus-frame');
    frame?.contentWindow?.postMessage(
      { giscus: { setConfig: { theme: effective() === 'dark' ? 'dark' : 'light' } } },
      'https://giscus.app',
    );
  };

  buttons.forEach((button) => {
    button.addEventListener('click', () => {
      const theme = nextTheme(html.dataset.theme, system.matches);
      html.dataset.theme = theme;
      try {
        localStorage.setItem(THEME_KEY, theme);
      } catch {
        // Storage blocked: the choice lasts for this page only.
      }
      updateLabels();
      syncGiscus();
    });
  });

  system.addEventListener('change', () => {
    updateLabels();
    syncGiscus();
  });

  let giscusReady = false;
  window.addEventListener('message', (event) => {
    if (event.origin !== 'https://giscus.app' || giscusReady) return;
    giscusReady = true;
    syncGiscus();
  });

  updateLabels();
}
```

Create `assets/js/menu.js`:

```js
// Full-screen menu for narrow screens: open, close, Escape, and a focus trap.

const CLOSE_MS = 600;

export function initMenu(root = document) {
  const menu = root.querySelector('[data-menu]');
  const openButton = root.querySelector('[data-menu-open]');
  if (!menu || !openButton) return;

  const html = document.documentElement;
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const focusable = () => [...menu.querySelectorAll('a[href], button:not([disabled])')];

  function open() {
    menu.hidden = false;
    requestAnimationFrame(() => menu.classList.add('is-open'));
    openButton.setAttribute('aria-expanded', 'true');
    html.classList.add('menu-open');
    focusable()[0]?.focus();
  }

  function close({ restoreFocus = true } = {}) {
    menu.classList.remove('is-open');
    openButton.setAttribute('aria-expanded', 'false');
    html.classList.remove('menu-open');
    const hide = () => {
      if (!menu.classList.contains('is-open')) menu.hidden = true;
    };
    if (reducedMotion.matches) hide();
    else setTimeout(hide, CLOSE_MS);
    if (restoreFocus) openButton.focus();
  }

  openButton.addEventListener('click', open);

  menu.querySelectorAll('[data-menu-close]').forEach((element) => {
    // The Contact link jumps to the footer, so focus should not return to the button.
    element.addEventListener('click', () => close({ restoreFocus: element.tagName === 'BUTTON' }));
  });

  menu.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      close();
      return;
    }
    if (event.key !== 'Tab') return;
    const items = focusable();
    const first = items[0];
    const last = items[items.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  });

  // Rotating a tablet or widening the window with the menu open: close it.
  window.matchMedia('(min-width: 800px)').addEventListener('change', (event) => {
    if (event.matches && !menu.hidden) close({ restoreFocus: false });
  });
}
```

Edit `assets/js/main.js`: add at the very top

```js
import { initMenu } from './menu.js';
import { initTheme } from './theme.js';
```

and at the bottom

```js
run('theme', () => initTheme());
run('menu', () => initMenu());
```

- [ ] **Step 5: Style the header, menu, footer and switch**

Append to `_sass/_layout.scss`:

```scss
.site-header {
  position: sticky;
  top: 0;
  z-index: 20;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  height: var(--header-h);
  padding: 0 var(--gutter);
  background: var(--color-bg);
  font-size: var(--fs-xs);
  transition: background-color 0.4s;
}

.site-header__name,
.site-nav a {
  text-decoration: none;
}

.site-nav {
  display: none;
  align-items: center;
  gap: clamp(1rem, 2.4vw, 2.6rem);
}

.site-nav a:hover,
.site-nav a[aria-current="page"] {
  text-decoration: underline;
}

@media (min-width: 800px) {
  .site-nav {
    display: flex;
  }

  .menu-button {
    display: none;
  }
}

.site-footer {
  padding: 18vh var(--gutter) var(--gutter);
}

.site-footer__grid {
  display: grid;
  gap: 3rem var(--gutter);
  padding-top: var(--gutter);
}

.site-footer__open,
.site-footer__contact {
  display: grid;
  gap: 1rem;
  align-content: start;
}

.site-footer__invite {
  max-width: 20ch;
  font-size: var(--fs-l);
  line-height: 1.05;
  letter-spacing: -0.035em;
}

.site-footer__links {
  display: grid;
  gap: 0.3em;
  list-style: none;
}

.site-footer__copy {
  font-size: var(--fs-xxs);
  color: var(--color-muted);
}

@media (min-width: 800px) {
  .site-footer__grid {
    grid-template-columns: repeat(12, minmax(0, 1fr));
  }

  .site-footer__open {
    grid-column: 1 / span 8;
  }

  .site-footer__contact {
    grid-column: 9 / span 4;
  }

  .site-footer__copy {
    grid-column: 1 / -1;
  }
}
```

Replace `_sass/_components.scss` with:

```scss
// Menu overlay (narrow screens)

html.menu-open {
  overflow: hidden;
}

.menu {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 0 var(--gutter) var(--gutter);
  background: var(--color-bg);
  clip-path: inset(0 0 100% 0);
  transition: clip-path 0.6s var(--ease-in-out);
}

.menu.is-open {
  clip-path: inset(0);
}

.menu__top,
.menu__bottom {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: var(--fs-xs);
}

.menu__top {
  height: var(--header-h);
}

.menu__links {
  display: grid;
  gap: 0.1em;
  font-size: clamp(2.6rem, 13vw, 6rem);
  font-weight: 500;
  line-height: 1;
  letter-spacing: -0.05em;
}

.menu__links a {
  text-decoration: none;
}

// Light/dark switch

.theme-toggle {
  position: relative;
  width: 1.9em;
  height: 1.05em;
  border: 1px solid currentColor;
  border-radius: 999px;
}

.theme-toggle__dot {
  position: absolute;
  top: 50%;
  left: 0.15em;
  width: 0.7em;
  height: 0.7em;
  border-radius: 50%;
  background: currentColor;
  transform: translateY(-50%);
  transition: transform 0.4s var(--ease-out);
}

:root[data-theme="dark"] .theme-toggle__dot {
  transform: translate(0.8em, -50%);
}

@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) .theme-toggle__dot {
    transform: translate(0.8em, -50%);
  }
}

// Shared bits

.link-arrow {
  display: inline-flex;
  gap: 0.4em;
  font-size: var(--fs-xs);
  text-decoration: none;
}

.link-arrow::after {
  content: "→";
  transition: transform 0.4s var(--ease-out);
}

.link-arrow:hover::after {
  transform: translateX(0.3em);
}
```

- [ ] **Step 6: Run the checks**

Run: `bash tools/check.sh`
Expected: PASS (all Python and node tests).

- [ ] **Step 7: Check in the browser**

Run `bundle exec jekyll serve --livereload` and open <http://127.0.0.1:4000/about/>.
- At 1440px: name left; Work (0), Archive (5), About (underlined), Search, Contact and the switch right. The switch flips the colours, and the choice survives a reload.
- At 375px: only "Menu" shows. It opens the overlay, Tab cycles inside it, Escape closes it and focus returns to "Menu", and "Contact" closes it and jumps to the footer.
- Press Tab once on a fresh page load: "Skip to content" appears top-left.

- [ ] **Step 8: Commit**

```bash
git add _includes _layouts/default.html _sass assets/js test
git commit -m "$(cat <<'EOF'
Add the header, phone menu, footer and light/dark switch

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Post page

Deliverable: posts show category, big title, date, tag pills, cover image, a table of contents (sticky beside the text on wide screens, collapsible on phones), giscus comments and a "Next post" link.

**Files:**
- Create: `assets/js/lib/toc-core.js`, `assets/js/toc.js`, `_includes/comments.html`, `test/js/toc.test.mjs`, `test/test_post.py`
- Modify: `_layouts/post.html` (full replacement), `_sass/_post.scss` (append), `assets/js/main.js`

**Interfaces:**
- Consumes: `run`; `find`, `read_page`.
- Produces: `buildTocItems(headings: {id, text, level}[]) -> {id, text, depth}[]` (empty when fewer than two usable headings); `initToc(root = document)`; hooks `[data-toc]`, `[data-toc-list]`, `[data-toc-source]`; classes `.tag-pills` (reused by later tasks).

- [ ] **Step 1: Write the failing tests**

Create `test/js/toc.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildTocItems } from '../../assets/js/lib/toc-core.js';

const h = (level, text, id = text.toLowerCase().replace(/\W+/g, '-')) => ({ id, text, level });

test('uses the top heading level present and the level below it', () => {
  const items = buildTocItems([h(3, 'Topology'), h(4, 'Detail'), h(3, 'Steps'), h(4, 'Deep'), h(5, 'Ignored')]);
  assert.deepEqual(items.map((i) => [i.text, i.depth]), [['Topology', 0], ['Detail', 1], ['Steps', 0], ['Deep', 1]]);
});

test('ignores deeper levels than one below the top', () => {
  const items = buildTocItems([h(2, 'A'), h(4, 'Too deep'), h(2, 'B')]);
  assert.deepEqual(items.map((i) => i.text), ['A', 'B']);
});

test('returns nothing when fewer than two headings remain', () => {
  assert.deepEqual(buildTocItems([]), []);
  assert.deepEqual(buildTocItems([h(2, 'Only')]), []);
  assert.deepEqual(buildTocItems([h(2, 'One'), h(4, 'Filtered out')]), []);
});

test('skips headings without an id or text, and trims text', () => {
  const items = buildTocItems([h(2, '  Spaced  ', 'spaced'), { id: '', text: 'No id', level: 2 }, h(2, '   ', 'blank'), h(2, 'Last')]);
  assert.deepEqual(items.map((i) => i.text), ['Spaced', 'Last']);
});

test('ignores h1 and h6', () => {
  assert.deepEqual(buildTocItems([h(1, 'Title'), h(6, 'Tiny')]), []);
});
```

Create `test/test_post.py`:

```python
import unittest

from helpers import find, read_page

POST = "/posts/Creating-a-redundant-network/"


class PostTest(unittest.TestCase):
    def setUp(self):
        self.html = read_page(POST)

    def test_header_shows_title_date_and_tags(self):
        self.assertTrue(find(self.html, "h1", cls="post__title"))
        times = [attrs["datetime"] for _, attrs in find(self.html, "time")]
        # The exact time depends on the build machine's time zone; the date is enough.
        self.assertTrue(any(value.startswith("2026-06-04") for value in times), times)
        self.assertTrue(find(self.html, "a", href="/tags/bgp/"))

    def test_cover_image_comes_from_front_matter(self):
        self.assertTrue(find(self.html, "img", src="/assets/img/Pasted%20image%2020260605145741.png"))

    def test_toc_container_and_source_exist(self):
        self.assertTrue(find(self.html, "aside", data_toc=""))
        self.assertTrue(find(self.html, "div", data_toc_source=""))

    def test_giscus_comments_are_configured(self):
        scripts = find(self.html, "script", src="https://giscus.app/client.js")
        self.assertEqual(len(scripts), 1)
        self.assertEqual(scripts[0][1]["data-repo"], "gonzalo-brandan/gonzalo-brandan.github.io")
        self.assertEqual(scripts[0][1]["data-mapping"], "pathname")

    def test_next_post_link_points_to_another_post(self):
        links = find(self.html, "a", cls="post__next-link")
        self.assertEqual(len(links), 1)
        self.assertTrue(links[0][1]["href"].startswith("/posts/"))
        self.assertNotEqual(links[0][1]["href"], POST)

    def test_newest_post_wraps_to_the_oldest(self):
        html = read_page("/posts/From-fundamentals-to-enterprise-complexity/")
        self.assertTrue(find(html, "a", cls="post__next-link", href="/posts/configure-a-basic-wlan-on-the-wlc/"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `bash tools/check.sh`
Expected: FAIL — `PostTest` failures and `Cannot find module .../lib/toc-core.js`.

- [ ] **Step 3: Write the TOC logic**

Create `assets/js/lib/toc-core.js`:

```js
// Turns a post's headings into a flat table-of-contents list.
// Uses the highest heading level present (h2–h4) and the level directly below it,
// because older posts start at h3 while newer ones start at h2.

export function buildTocItems(headings) {
  const usable = headings.filter((h) => h.id && h.text.trim() && h.level >= 2 && h.level <= 4);
  if (usable.length < 2) return [];
  const top = Math.min(...usable.map((h) => h.level));
  const items = usable
    .filter((h) => h.level <= top + 1)
    .map((h) => ({ id: h.id, text: h.text.trim(), depth: h.level - top }));
  return items.length >= 2 ? items : [];
}
```

Create `assets/js/toc.js`:

```js
// Table of contents: built from the post's headings, open beside the text on wide
// screens, collapsed above it on phones, highlighting the section being read.

import { buildTocItems } from './lib/toc-core.js';

export function initToc(root = document) {
  const toc = root.querySelector('[data-toc]');
  const source = root.querySelector('[data-toc-source]');
  if (!toc || !source) return;

  const headingElements = [...source.querySelectorAll('h2, h3, h4')];
  const items = buildTocItems(headingElements.map((el) => ({
    id: el.id,
    text: el.textContent,
    level: Number(el.tagName[1]),
  })));
  if (items.length === 0) return;

  const list = toc.querySelector('[data-toc-list]');
  const links = new Map();
  for (const item of items) {
    const li = document.createElement('li');
    li.className = `toc__item toc__item--depth-${item.depth}`;
    const a = document.createElement('a');
    a.href = `#${item.id}`;
    a.textContent = item.text;
    li.append(a);
    list.append(li);
    links.set(item.id, a);
  }
  toc.hidden = false;

  const details = toc.querySelector('details');
  const wide = window.matchMedia('(min-width: 1000px)');
  const syncOpen = () => { details.open = wide.matches; };
  syncOpen();
  wide.addEventListener('change', syncOpen);

  if (!('IntersectionObserver' in window)) return;
  const observer = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      links.forEach((link) => link.removeAttribute('aria-current'));
      links.get(entry.target.id)?.setAttribute('aria-current', 'true');
    }
  }, { rootMargin: '0px 0px -70% 0px' });
  headingElements.filter((el) => links.has(el.id)).forEach((el) => observer.observe(el));
}
```

Edit `assets/js/main.js`: add `import { initToc } from './toc.js';` to the imports and `run('toc', () => initToc());` at the bottom.

- [ ] **Step 4: Write the post layout and comments**

Create `_includes/comments.html`:

```html
{% assign giscus = site.comments.giscus %}
<section class="post__comments" aria-label="Comments">
  <p class="label">[ Comments ]</p>
  <script src="https://giscus.app/client.js"
    data-repo="{{ giscus.repo }}"
    data-repo-id="{{ giscus.repo_id }}"
    data-category="{{ giscus.category }}"
    data-category-id="{{ giscus.category_id }}"
    data-mapping="{{ giscus.mapping | default: 'pathname' }}"
    data-strict="0"
    data-reactions-enabled="1"
    data-emit-metadata="0"
    data-input-position="bottom"
    data-theme="preferred_color_scheme"
    data-lang="{{ site.lang | default: 'en' }}"
    data-loading="lazy"
    crossorigin="anonymous"
    async></script>
</section>
```

Replace `_layouts/post.html` with:

```html
---
layout: default
---
{% assign topic = page.categories | first | capitalize %}
<article class="post">
  <header class="post__header">
    {% if topic != "" %}<p class="label" data-reveal="line">[ {{ topic }} ]</p>{% endif %}
    <h1 class="post__title" data-reveal="line">{{ page.title }}</h1>
    <div class="post__meta" data-reveal="line">
      <time datetime="{{ page.date | date_to_xmlschema }}">{{ page.date | date: '%d %B %Y' }}</time>
      {% if page.tags.size > 0 %}
        <ul class="tag-pills" aria-label="Tags">
          {% for tag in page.tags %}
            {% assign slug = tag | slugify %}
            <li><a href="{{ '/tags/' | append: slug | append: '/' | relative_url }}">{{ tag }}</a></li>
          {% endfor %}
        </ul>
      {% endif %}
    </div>
    <hr class="rule" data-reveal="rule">
  </header>

  {% if page.image %}
    {% assign cover = page.image.path | default: page.image %}
    <figure class="post__cover" data-reveal="image">
      <img src="{{ cover | relative_url | uri_escape }}" alt="{{ page.image.alt | default: '' | escape }}">
    </figure>
  {% endif %}

  <div class="post__layout">
    {% if page.toc %}
      <aside class="post__toc" data-toc hidden>
        <details>
          <summary class="label">[ Contents ]</summary>
          <nav aria-label="Table of contents">
            <ol class="toc__list" data-toc-list></ol>
          </nav>
        </details>
      </aside>
    {% endif %}
    <div class="prose" data-toc-source>
      {{ content }}
    </div>
  </div>

  {% assign next = page.next | default: site.posts.last %}
  {% if next and next.url != page.url %}
    <nav class="post__next" aria-label="Next post">
      <p class="label" data-reveal="line">[ Next post ]</p>
      <a class="post__next-link" href="{{ next.url | relative_url }}" data-reveal="line">{{ next.title }}</a>
    </nav>
  {% endif %}

  {% if page.comments %}{% include comments.html %}{% endif %}
</article>
```

- [ ] **Step 5: Style the post page**

Append to `_sass/_post.scss`:

```scss
.post__header {
  display: grid;
  gap: 1.4rem;
  padding: 12vh 0 3rem;
}

.post__title {
  max-width: 22ch;
  font-size: clamp(2rem, 5vw, 6rem);
  line-height: 1;
  letter-spacing: -0.045em;
  overflow-wrap: break-word;
}

.post__meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.8rem 1.2rem;
  font-size: var(--fs-xs);
  color: var(--color-muted);
}

.tag-pills {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  list-style: none;
}

.tag-pills a {
  display: inline-block;
  padding: 0.25em 0.7em;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  font-size: var(--fs-xxs);
  text-decoration: none;
  transition: background-color 0.3s, color 0.3s, border-color 0.3s;
}

.tag-pills a:hover {
  border-color: transparent;
  background: var(--color-accent);
  color: var(--color-accent-text);
}

.post__cover {
  display: grid;
  place-items: center;
  margin-bottom: 4rem;
  padding: clamp(1rem, 4vw, 4rem);
  border-radius: var(--radius);
  background: var(--color-surface);
}

.post__cover img {
  width: auto;
  max-height: 70vh;
}

.post__layout {
  display: grid;
  gap: 2rem var(--gutter);
}

.post__toc {
  font-size: var(--fs-xs);
}

.post__toc summary {
  padding-bottom: 0.8rem;
  cursor: pointer;
  list-style: none;
}

.post__toc summary::-webkit-details-marker {
  display: none;
}

.toc__list {
  display: grid;
  gap: 0.45em;
  border-left: 1px solid var(--color-border);
  list-style: none;
}

.toc__item a {
  display: block;
  margin-left: -1px;
  padding-left: 0.9em;
  border-left: 1px solid transparent;
  color: var(--color-muted);
  text-decoration: none;
  transition: color 0.3s, border-color 0.3s;
}

.toc__item--depth-1 a {
  padding-left: 1.8em;
}

.toc__item a:hover,
.toc__item a[aria-current="true"] {
  border-left-color: currentColor;
  color: var(--color-text);
}

@media (min-width: 1000px) {
  .post__layout {
    grid-template-columns: repeat(12, minmax(0, 1fr));
  }

  .post__toc {
    position: sticky;
    top: calc(var(--header-h) + 1.5rem);
    grid-row: 1;
    grid-column: 1 / span 3;
    align-self: start;
    max-height: calc(100vh - var(--header-h) - 3rem);
    overflow: auto;
  }

  .post__layout .prose {
    grid-column: 4 / span 8;
  }
}

.post__next {
  display: grid;
  gap: 1rem;
  padding: 12vh 0 4vh;
}

.post__next-link {
  max-width: 16ch;
  font-size: var(--fs-xl);
  font-weight: 500;
  line-height: 0.92;
  letter-spacing: -0.05em;
  text-decoration: none;
}

.post__next-link:hover {
  text-decoration: underline;
  text-decoration-thickness: 0.04em;
}

.post__comments {
  display: grid;
  gap: 1.5rem;
  max-width: 900px;
  padding: 4vh 0;
}
```

- [ ] **Step 6: Run the checks**

Run: `bash tools/check.sh`
Expected: PASS. If `test_cover_image_comes_from_front_matter` fails, print the `src` actually rendered (`grep -o 'post__cover.*' _site/posts/Creating-a-redundant-network/index.html | head -c 300`) and make sure the layout uses `relative_url | uri_escape`.

- [ ] **Step 7: Check in the browser**

Open <http://127.0.0.1:4000/posts/Creating-a-redundant-network/>:
- At 1440px the contents list sits beside the text and stays visible while scrolling, and the current section is highlighted.
- At 375px it's collapsed above the text as "[ Contents ]" and opens on tap.
- The WLAN post (which starts at `###` headings) also gets a contents list.
- Comments load at the bottom, and switching the theme switches the comments theme.
- Config blocks scroll sideways inside their box, and the page itself never scrolls sideways.

- [ ] **Step 8: Commit**

```bash
git add _layouts/post.html _includes/comments.html _sass/_post.scss assets/js test
git commit -m "$(cat <<'EOF'
Build the post page with contents, comments and a next-post link

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Home and Work pages with featured projects

Deliverable: the home page hero, approach block and featured project cards; the Work page listing the featured projects; two posts marked as featured.

**Files:**
- Create: `_includes/project-card.html`, `_layouts/work.html`, `work.md`, `test/test_home_work.py`
- Modify: `_layouts/home.html` (full replacement), `index.html`, `_sass/_components.scss` (append), `_posts/2026-06-05-Creating-a-redundant-network.md` and `_posts/2026-06-26-From-fundamentals-to-enterprise-complexity.md` (front matter only)

**Interfaces:**
- Consumes: `find`, `read_page`, `featured_post_count`; `.page-head`, `.page-title`, `.label`, `.rule`, `.link-arrow`.
- Produces: include `project-card.html` taking `post` and `index`; front matter keys `featured: true` and `summary:`; `data-reveal` values `line`, `rule`, `image`, `grow` (animated in Task 8).

- [ ] **Step 1: Write the failing tests**

Create `test/test_home_work.py`:

```python
import unittest

from helpers import featured_post_count, find, read_page

FEATURED = {
    "/posts/Creating-a-redundant-network/",
    "/posts/From-fundamentals-to-enterprise-complexity/",
}


def card_links(html):
    return {attrs["href"] for _, attrs in find(html, "a", cls="project-card__link")}


class HomeWorkTest(unittest.TestCase):
    def test_two_posts_are_featured(self):
        self.assertEqual(featured_post_count(), 2)

    def test_home_hero_says_the_tagline(self):
        html = read_page("/")
        self.assertTrue(find(html, "h1", cls="hero__title"))
        for line in ("I like solving", "infrastructure", "problems."):
            self.assertIn(line, html)
        self.assertIn("[ Berlin ]", html)

    def test_home_lists_the_featured_projects(self):
        self.assertEqual(card_links(read_page("/")), FEATURED)

    def test_work_page_lists_the_featured_projects(self):
        html = read_page("/work/")
        self.assertEqual(card_links(html), FEATURED)
        self.assertIn("[ Work ]", html)

    def test_cards_have_image_summary_and_year(self):
        html = read_page("/work/")
        self.assertEqual(len(find(html, "div", cls="project-card__media")), 2)
        self.assertEqual(len(find(html, "p", cls="project-card__summary")), 2)
        self.assertIn("2026", html)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `bash tools/check.sh`
Expected: FAIL — `HomeWorkTest` failures (no featured posts, no `/work/`).

- [ ] **Step 3: Mark the featured posts**

In `_posts/2026-06-05-Creating-a-redundant-network.md`, add these two lines to the front matter directly after `layout: post`:

```yaml
featured: true
summary: "An enterprise network with redundancy at every layer: dual ISPs with BGP, HSRP at the edge and core, port-channels, VLANs, DHCP and NAT, tested by failing devices on purpose."
```

In `_posts/2026-06-26-From-fundamentals-to-enterprise-complexity.md`, add directly after `layout: post`:

```yaml
featured: true
summary: "One living topology that grows with every new skill: VLSM, VLANs, router-on-a-stick, centralized DHCP, multi-area OSPF and NAT across a main site and two branches."
```

- [ ] **Step 4: Write the card, layouts and pages**

Create `_includes/project-card.html`:

```html
{% assign p = include.post %}
<article class="project-card" data-reveal="image">
  <a class="project-card__link" href="{{ p.url | relative_url }}">
    <div class="project-card__media">
      {% if p.image %}
        {% assign src = p.image.path | default: p.image %}
        <img src="{{ src | relative_url | uri_escape }}" alt="{{ p.image.alt | default: '' | escape }}" loading="lazy" decoding="async">
      {% else %}
        <span class="project-card__placeholder">{{ p.title }}</span>
      {% endif %}
    </div>
    <div class="project-card__info">
      <span class="project-card__index">{{ include.index | prepend: '0' }}</span>
      <h3 class="project-card__title">{{ p.title }}</h3>
      {% if p.summary %}<p class="project-card__summary">{{ p.summary }}</p>{% endif %}
      <p class="project-card__meta">{{ p.tags | slice: 0, 4 | join: ' · ' }} — {{ p.date | date: '%Y' }}</p>
    </div>
  </a>
</article>
```

Replace `index.html` with:

```html
---
layout: home
hero_lines:
  - I like solving
  - infrastructure
  - problems.
hero_image_line: 2
role: Networking, data center hardware and automation, based in Berlin.
approach: Find the root cause, fix it properly, and write down how, so the next person doesn't have to guess.
---
```

Replace `_layouts/home.html` with:

```html
---
layout: default
---
{% assign featured = site.posts | where: "featured", true %}
{% assign hero_post = featured | first %}
<section class="hero">
  <h1 class="hero__title">
    {% for line in page.hero_lines %}
      <span class="hero__line" data-reveal="line">
        {% if forloop.index == page.hero_image_line and hero_post.image %}
          {% assign src = hero_post.image.path | default: hero_post.image %}
          <span class="hero__image" data-reveal="grow"><img src="{{ src | relative_url | uri_escape }}" alt=""></span>
        {% endif %}{{ line }}
      </span>
    {% endfor %}
  </h1>
  <div class="hero__aside">
    <p class="hero__role" data-reveal="line">{{ page.role }}</p>
    <p class="label" data-reveal="line">[ {{ site.location }} ]</p>
  </div>
</section>

<section class="approach">
  <p class="label" data-reveal="line">[ Approach ]</p>
  <p class="approach__text" data-reveal="line">{{ page.approach }}</p>
  <a class="link-arrow approach__link" href="{{ '/about/' | relative_url }}">More about me</a>
</section>

{% if featured.size > 0 %}
<section class="featured" aria-labelledby="featured-title">
  <div class="section-head">
    <h2 class="section-title" id="featured-title" data-reveal="line">Selected work</h2>
    <a class="link-arrow" href="{{ '/work/' | relative_url }}">See all work</a>
  </div>
  <hr class="rule" data-reveal="rule">
  <div class="project-grid">
    {% for post in featured %}{% include project-card.html post=post index=forloop.index %}{% endfor %}
  </div>
</section>
{% endif %}
```

Create `_layouts/work.html`:

```html
---
layout: default
---
{% assign featured = site.posts | where: "featured", true %}
<section class="page-head">
  <p class="label" data-reveal="line">[ Work ]</p>
  <h1 class="page-title" data-reveal="line">{{ page.heading | default: page.title }}</h1>
  <div class="page-head__aside">
    <p class="page-head__intro" data-reveal="line">{{ page.intro }}</p>
    {% if featured.size > 0 %}
      {% assign newest = featured.first.date | date: '%Y' %}
      {% assign oldest = featured.last.date | date: '%Y' %}
      <p class="label" data-reveal="line">{% if oldest == newest %}{{ newest }}{% else %}{{ oldest }} – {{ newest }}{% endif %}</p>
    {% endif %}
  </div>
</section>
<hr class="rule" data-reveal="rule">
<div class="project-grid project-grid--stacked">
  {% for post in featured %}{% include project-card.html post=post index=forloop.index %}{% endfor %}
</div>
```

Create `work.md`:

```markdown
---
layout: work
title: Work
heading: Projects
permalink: /work/
intro: Two networks I built from an empty topology to a working design, with every decision, configuration and failure written down.
---
```

- [ ] **Step 5: Style the hero, approach and cards**

Append to `_sass/_components.scss`:

```scss
// Home

.hero {
  display: grid;
  gap: 3rem;
  padding: 14vh 0 10vh;
}

.hero__title {
  font-size: var(--fs-xl);
  line-height: 0.9;
  letter-spacing: -0.055em;
  overflow-wrap: break-word;
}

.hero__line {
  display: block;
}

.hero__image {
  display: none;
  overflow: hidden;
  width: 1.6em;
  height: 0.72em;
  margin: 0 0.12em;
  border-radius: var(--radius);
  background: var(--color-surface);
  vertical-align: 0.02em;
}

.hero__image img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

@media (min-width: 600px) {
  .hero__image {
    display: inline-block;
  }
}

.hero__aside {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 2rem;
  font-size: var(--fs-m);
}

.hero__role {
  max-width: 24ch;
}

.approach {
  display: grid;
  gap: 1.5rem var(--gutter);
  padding: 6vh 0 14vh;
}

.approach__text {
  max-width: 22ch;
  font-size: var(--fs-l);
  line-height: 1.05;
  letter-spacing: -0.035em;
}

@media (min-width: 800px) {
  .approach {
    grid-template-columns: repeat(12, minmax(0, 1fr));
  }

  .approach .label {
    grid-column: 1 / span 3;
  }

  .approach__text,
  .approach__link {
    grid-column: 4 / span 8;
  }
}

.section-head {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 1rem;
  padding-bottom: 1.2rem;
}

.section-title {
  font-size: var(--fs-xl);
  line-height: 0.9;
  letter-spacing: -0.055em;
}

// Project cards

.project-grid {
  display: grid;
  gap: 4rem var(--gutter);
  padding: 2rem 0 6vh;
}

@media (min-width: 800px) {
  .project-grid {
    grid-template-columns: 1fr 1fr;
  }
}

.project-grid.project-grid--stacked {
  grid-template-columns: 1fr;
}

.project-card__link {
  display: grid;
  gap: 1rem;
  text-decoration: none;
}

.project-card__media {
  display: grid;
  place-items: center;
  overflow: hidden;
  aspect-ratio: 4 / 3;
  border-radius: var(--radius);
  background: var(--color-surface);
}

.project-grid--stacked .project-card__media {
  aspect-ratio: 16 / 9;
}

.project-card__media img {
  width: 100%;
  height: 100%;
  padding: 6%;
  object-fit: contain;
  transition: transform 1s var(--ease-out);
}

.project-card__link:hover .project-card__media img {
  transform: scale(1.04);
}

.project-card__placeholder {
  padding: 1rem;
  font-size: var(--fs-l);
  text-align: center;
}

.project-card__info {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 0.4rem 1rem;
}

.project-card__index {
  padding-top: 0.4em;
  font-size: var(--fs-xxs);
  color: var(--color-muted);
}

.project-card__title {
  font-size: var(--fs-m);
  line-height: 1.1;
  letter-spacing: -0.02em;
}

.project-card__summary,
.project-card__meta {
  grid-column: 2;
}

.project-card__summary {
  max-width: 52ch;
  font-size: var(--fs-xs);
  color: var(--color-muted);
}

.project-card__meta {
  font-size: var(--fs-xxs);
  color: var(--color-muted);
}
```

- [ ] **Step 6: Run the checks**

Run: `bash tools/check.sh`
Expected: PASS, including `ShellTest.test_nav_shows_live_counts` now reading "Work (2)".

- [ ] **Step 7: Check in the browser**

Open <http://127.0.0.1:4000/> and <http://127.0.0.1:4000/work/>:
- At 1440px the hero fills the width in three lines, with a small image box before "infrastructure".
- At 375px and 320px the hero wraps without sideways scrolling and the image box is hidden. Check with: `document.documentElement.scrollWidth <= innerWidth` in the console must be `true`.
- Both project cards show their diagram and link to the right post.

- [ ] **Step 8: Commit**

```bash
git add index.html work.md _layouts/home.html _layouts/work.html _includes/project-card.html _sass/_components.scss _posts test
git commit -m "$(cat <<'EOF'
Add the home hero, Work page and featured project cards

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Archive list, tag pages and the cursor image

Deliverable: Archive and every tag page list posts as Name / Topic / Date rows; on mouse devices hovering a row shows its image following the cursor.

**Files:**
- Create: `_includes/archive-list.html`, `assets/js/lib/motion.js`, `assets/js/cursor-image.js`, `test/test_archive.py`, `test/js/cursor-image.test.mjs`
- Modify: `_layouts/archive.html`, `_layouts/tag.html` (full replacements), `_sass/_components.scss` (append), `assets/js/main.js`

**Interfaces:**
- Consumes: `run`; `find`, `read_page`, `dated_post_count`; `.page-head`, `.page-title`, `.page-head__aside`, `.page-head__intro`, `.label`, `.rule`.
- Produces: include `archive-list.html` taking `posts`; `prefersReducedMotion() -> boolean` in `lib/motion.js`; `lerp(from, to, amount) -> number` and `initCursorImage(root = document)` in `cursor-image.js`; hooks `[data-cursor-area]`, `[data-cursor-image]`, `[data-cursor-preview]`; classes `.archive__list`, `.archive__row`, `.archive__link`, `.archive__name`, `.archive__topic`, `.archive__date` (Task 7 reuses them for search results).

- [ ] **Step 1: Write the failing tests**

Create `test/test_archive.py`:

```python
import unittest

from helpers import dated_post_count, find, read_page


class ArchiveTest(unittest.TestCase):
    def test_archive_lists_every_post_as_a_row(self):
        html = read_page("/archives/")
        self.assertEqual(len(find(html, "li", cls="archive__row")), dated_post_count())
        self.assertIn("[ Name ]", html)
        self.assertIn("[ Topic ]", html)
        self.assertIn("[ Date ]", html)

    def test_rows_carry_their_image_for_the_cursor_preview(self):
        html = read_page("/archives/")
        rows = find(html, "li", cls="archive__row")
        self.assertTrue(all(attrs.get("data-cursor-image", "").startswith("/assets/img/") for _, attrs in rows))
        self.assertEqual(len(find(html, "div", data_cursor_preview="")), 1)

    def test_topic_comes_from_the_category(self):
        html = read_page("/archives/")
        self.assertIn("Networking", html)
        self.assertIn("Projects", html)

    def test_tag_page_lists_only_its_posts(self):
        html = read_page("/tags/bgp/")
        rows = find(html, "a", cls="archive__link")
        self.assertEqual([attrs["href"] for _, attrs in rows], ["/posts/Creating-a-redundant-network/"])
        self.assertIn("[ Tag ]", html)

    def test_tag_index_links_to_tag_pages(self):
        html = read_page("/tags/")
        self.assertTrue(find(html, "a", href="/tags/cisco/"))


if __name__ == "__main__":
    unittest.main()
```

Create `test/js/cursor-image.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { lerp } from '../../assets/js/cursor-image.js';

test('lerp moves part of the way', () => {
  assert.equal(lerp(0, 100, 0.25), 25);
  assert.equal(lerp(100, 0, 0.5), 50);
});

test('lerp with amount 1 jumps to the target (reduced motion)', () => {
  assert.equal(lerp(12, 340, 1), 340);
});
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `bash tools/check.sh`
Expected: FAIL — `ArchiveTest` failures and `Cannot find module .../cursor-image.js`.

- [ ] **Step 3: Write the list include and layouts**

Create `_includes/archive-list.html`:

```html
<div class="archive" data-cursor-area>
  <div class="archive__head" aria-hidden="true">
    <span>[ Name ]</span><span>[ Topic ]</span><span>[ Date ]</span>
  </div>
  <hr class="rule" data-reveal="rule">
  <ol class="archive__list">
    {% for post in include.posts %}
      {% assign topic = post.categories | first | capitalize %}
      <li class="archive__row"{% if post.image %} data-cursor-image="{{ post.image.path | default: post.image | relative_url | uri_escape }}"{% endif %}>
        <a class="archive__link" href="{{ post.url | relative_url }}">
          <span class="archive__name">{{ post.title }}</span>
          <span class="archive__topic">{{ topic }}</span>
          <time class="archive__date" datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: '%b %Y' }}</time>
        </a>
        <hr class="rule" data-reveal="rule">
      </li>
    {% endfor %}
  </ol>
  <div class="cursor-image" aria-hidden="true" data-cursor-preview></div>
</div>
```

Replace `_layouts/archive.html` with:

```html
---
layout: default
---
{% assign newest = site.posts.first.date | date: '%Y' %}
{% assign oldest = site.posts.last.date | date: '%Y' %}
<section class="page-head">
  <p class="label" data-reveal="line">[ Archive ]</p>
  <h1 class="page-title" data-reveal="line">{{ page.heading | default: page.title }}</h1>
  <div class="page-head__aside">
    <p class="page-head__intro" data-reveal="line">{{ page.intro }}</p>
    <p class="label" data-reveal="line">{% if oldest == newest %}{{ newest }}{% else %}{{ oldest }} – {{ newest }}{% endif %}</p>
  </div>
</section>
{% include archive-list.html posts=site.posts %}
```

Replace `_layouts/tag.html` with:

```html
---
layout: default
---
<section class="page-head">
  <p class="label" data-reveal="line">[ Tag ]</p>
  <h1 class="page-title" data-reveal="line">{{ page.title }}</h1>
  <div class="page-head__aside">
    <p class="page-head__intro" data-reveal="line">{{ page.posts.size }} post{% if page.posts.size != 1 %}s{% endif %}</p>
    <a class="link-arrow" href="{{ '/tags/' | relative_url }}">All tags</a>
  </div>
</section>
{% include archive-list.html posts=page.posts %}
```

- [ ] **Step 4: Write the cursor image**

Create `assets/js/lib/motion.js`:

```js
// True when the visitor's system asks for less motion.
export function prefersReducedMotion() {
  return typeof window !== 'undefined'
    && typeof window.matchMedia === 'function'
    && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}
```

Create `assets/js/cursor-image.js`:

```js
// Archive: on mouse devices, hovering a row shows that post's image beside the cursor,
// following it with a slight lag.

import { prefersReducedMotion } from './lib/motion.js';

export function lerp(from, to, amount) {
  return from + (to - from) * amount;
}

export function initCursorImage(root = document) {
  const area = root.querySelector('[data-cursor-area]');
  const preview = area?.querySelector('[data-cursor-preview]');
  if (!area || !preview) return;
  if (!window.matchMedia('(hover: hover) and (pointer: fine)').matches) return;

  const img = document.createElement('img');
  img.alt = '';
  img.decoding = 'async';
  preview.append(img);

  const amount = prefersReducedMotion() ? 1 : 0.15;
  const target = { x: 0, y: 0 };
  const position = { x: 0, y: 0 };
  let visible = false;
  let frame = 0;

  const tick = () => {
    position.x = lerp(position.x, target.x, amount);
    position.y = lerp(position.y, target.y, amount);
    preview.style.transform = `translate3d(${position.x}px, ${position.y}px, 0)`;
    frame = visible ? requestAnimationFrame(tick) : 0;
  };

  const hide = () => {
    visible = false;
    preview.classList.remove('is-visible');
  };

  area.addEventListener('pointermove', (event) => {
    target.x = event.clientX;
    target.y = event.clientY;
  });

  area.querySelectorAll('.archive__row').forEach((row) => {
    row.addEventListener('pointerenter', (event) => {
      const src = row.dataset.cursorImage;
      if (!src) {
        hide();
        return;
      }
      if (!visible) {
        position.x = target.x = event.clientX;
        position.y = target.y = event.clientY;
      }
      img.src = src;
      visible = true;
      preview.classList.add('is-visible');
      if (!frame) frame = requestAnimationFrame(tick);
    });
  });

  area.addEventListener('pointerleave', hide);
}
```

Edit `assets/js/main.js`: add `import { initCursorImage } from './cursor-image.js';` to the imports and `run('cursor image', () => initCursorImage());` at the bottom.

- [ ] **Step 5: Style the archive and tag index**

Append to `_sass/_components.scss`:

```scss
// Archive list (also used by tag pages and search results)

.archive {
  position: relative;
  padding-bottom: 6vh;
}

.archive__head,
.archive__link {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 0.3rem var(--gutter);
}

.archive__head {
  padding-bottom: 0.8rem;
  font-size: var(--fs-xxs);
  color: var(--color-muted);
}

.archive__head span:nth-child(2) {
  display: none;
}

.archive__list {
  list-style: none;
}

.archive__link {
  align-items: baseline;
  padding: 1.1rem 0;
  text-decoration: none;
  transition: padding 0.5s var(--ease-out), color 0.3s;
}

.archive__name {
  font-size: var(--fs-m);
  line-height: 1.15;
  letter-spacing: -0.02em;
}

.archive__topic,
.archive__date {
  font-size: var(--fs-xs);
  color: var(--color-muted);
}

.archive__topic {
  grid-row: 2;
}

.archive__date {
  grid-row: 1;
  grid-column: 2;
  white-space: nowrap;
}

@media (min-width: 800px) {
  .archive__head,
  .archive__link {
    grid-template-columns: 6fr 3fr 2fr;
  }

  .archive__head span:nth-child(2) {
    display: block;
  }

  .archive__head span:last-child,
  .archive__date {
    text-align: right;
  }

  .archive__topic,
  .archive__date {
    grid-row: auto;
    grid-column: auto;
  }
}

@media (hover: hover) and (min-width: 800px) {
  .archive__list:hover .archive__link {
    color: var(--color-muted);
  }

  .archive__list .archive__link:hover {
    padding-left: 1rem;
    color: var(--color-text);
  }
}

.cursor-image {
  position: fixed;
  top: 0;
  left: 0;
  z-index: 30;
  width: clamp(180px, 22vw, 360px);
  pointer-events: none;
  opacity: 0;
  transition: opacity 0.35s;
}

.cursor-image.is-visible {
  opacity: 1;
}

.cursor-image img {
  width: 100%;
  border-radius: var(--radius);
  background: var(--color-surface);
  transform: translate(1.5rem, -50%);
}

// Tag index

.tag-index {
  display: flex;
  flex-wrap: wrap;
  gap: 0.2em 0.6em;
  list-style: none;
  font-size: var(--fs-l);
  line-height: 1.1;
  letter-spacing: -0.03em;
}

.tag-index a {
  text-decoration: none;
}

.tag-index a:hover {
  text-decoration: underline;
}
```

- [ ] **Step 6: Run the checks**

Run: `bash tools/check.sh`
Expected: PASS.

- [ ] **Step 7: Check in the browser**

Open <http://127.0.0.1:4000/archives/> at 1440px: moving over the rows shows each post's diagram next to the cursor, following it smoothly; other rows dim; leaving the list hides the image. At 375px rows show name, topic and date without sideways scroll and no image appears on tap. Open <http://127.0.0.1:4000/tags/> and <http://127.0.0.1:4000/tags/cisco/>.

- [ ] **Step 8: Commit**

```bash
git add _includes/archive-list.html _layouts/archive.html _layouts/tag.html _sass/_components.scss assets/js test
git commit -m "$(cat <<'EOF'
Add the archive list, tag pages and hover image preview

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: About page and 404 page

Deliverable: About with the large intro, zooming photo, text, numbered "What I build" block and location; a styled 404 page.

**Files:**
- Create: `_layouts/about.html`, `assets/js/photo-scale.js`, `404.html`, `test/test_about.py`, `test/js/photo-scale.test.mjs`
- Modify: `about.md` (full replacement), `_sass/_components.scss` (append), `assets/js/main.js`

**Interfaces:**
- Consumes: `run`; `prefersReducedMotion` from `lib/motion.js`; `find`, `read_page`, `built_file`.
- Produces: `scaleForProgress(progress) -> number` (1.3 → 1.0, clamped), `scrollProgress(scrollY, scrollHeight, viewportHeight) -> number` (0–1, 0 when the page doesn't scroll), `initPhotoScale(root = document)`; hook `[data-photo-scale]`; front matter keys `intro`, `skills: [{title, text}]` on About.

- [ ] **Step 1: Write the failing tests**

Create `test/js/photo-scale.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { scaleForProgress, scrollProgress } from '../../assets/js/photo-scale.js';

const near = (actual, expected) => assert.ok(Math.abs(actual - expected) < 1e-9, `${actual} ≉ ${expected}`);

test('scale goes from 1.3 at the top to 1.0 at the bottom', () => {
  near(scaleForProgress(0), 1.3);
  near(scaleForProgress(1), 1);
  near(scaleForProgress(0.5), 1.15);
});

test('scale is clamped outside 0..1 (overscroll)', () => {
  near(scaleForProgress(-0.2), 1.3);
  near(scaleForProgress(1.4), 1);
});

test('progress is 0 when the page is not taller than the window', () => {
  assert.equal(scrollProgress(0, 800, 800), 0);
  assert.equal(scrollProgress(0, 600, 800), 0);
});

test('progress is the scrolled share of the scrollable height', () => {
  assert.equal(scrollProgress(500, 2000, 1000), 0.5);
});
```

Create `test/test_about.py`:

```python
import unittest

from helpers import built_file, find, read_page


class AboutTest(unittest.TestCase):
    def setUp(self):
        self.html = read_page("/about/")

    def test_intro_photo_and_text(self):
        self.assertIn("I like solving infrastructure problems", self.html)
        self.assertTrue(find(self.html, "img", data_photo_scale="", src="/assets/static/Image.jpeg"))
        self.assertIn("How I got here", self.html)
        self.assertIn("1,300-guest hotel", self.html)

    def test_what_i_build_is_numbered(self):
        self.assertEqual(len(find(self.html, "article", cls="skill")), 3)
        for index in ("01", "02", "03"):
            self.assertIn(f'<span class="skill__index">{index}</span>', self.html)

    def test_404_page(self):
        self.assertTrue(built_file("/404.html").is_file())
        html = read_page("/404.html")
        self.assertIn("[ 404 ]", html)
        self.assertTrue(find(html, "a", href="/archives/"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `bash tools/check.sh`
Expected: FAIL — `AboutTest` failures and `Cannot find module .../photo-scale.js`.

- [ ] **Step 3: Write the photo scale**

Create `assets/js/photo-scale.js`:

```js
// About: the photo zooms out from 1.3 to 1.0 as the page scrolls.

import { prefersReducedMotion } from './lib/motion.js';

export function scaleForProgress(progress) {
  const clamped = Math.min(Math.max(progress, 0), 1);
  return 1.3 - 0.3 * clamped;
}

export function scrollProgress(scrollY, scrollHeight, viewportHeight) {
  const scrollable = scrollHeight - viewportHeight;
  return scrollable > 0 ? scrollY / scrollable : 0;
}

export function initPhotoScale(root = document) {
  const photo = root.querySelector('[data-photo-scale]');
  if (!photo || prefersReducedMotion()) return;

  let ticking = false;
  const update = () => {
    ticking = false;
    const progress = scrollProgress(window.scrollY, document.documentElement.scrollHeight, window.innerHeight);
    photo.style.transform = `scale(${scaleForProgress(progress)})`;
  };

  window.addEventListener('scroll', () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(update);
  }, { passive: true });
  window.addEventListener('resize', update);
  update();
}
```

Edit `assets/js/main.js`: add `import { initPhotoScale } from './photo-scale.js';` to the imports and `run('photo scale', () => initPhotoScale());` at the bottom.

- [ ] **Step 4: Write the About layout, content and 404**

Create `_layouts/about.html`:

```html
---
layout: default
---
<section class="about-hero">
  <p class="label" data-reveal="line">[ About ]</p>
  <p class="about-hero__intro" data-reveal="line">{{ page.intro }}</p>
</section>

<div class="about-grid">
  <figure class="about-photo-frame" data-reveal="image">
    <img class="about-photo" data-photo-scale src="{{ site.avatar | relative_url }}" alt="{{ site.author }}" width="1268" height="1240">
  </figure>
  <div class="prose about-body">
    {{ content }}
  </div>
</div>

{% if page.skills %}
<section class="skills" aria-labelledby="skills-title">
  <h2 class="visually-hidden" id="skills-title">What I build</h2>
  {% for skill in page.skills %}
    <article class="skill">
      <hr class="rule" data-reveal="rule">
      <div class="skill__head">
        <h3 data-reveal="line">{{ skill.title }}</h3>
        <span class="skill__index">{{ forloop.index | prepend: '0' }}</span>
      </div>
      <p data-reveal="line">{{ skill.text }}</p>
    </article>
  {% endfor %}
</section>
{% endif %}

<section class="location">
  <p class="location__title" data-reveal="line">Based in {{ site.location }}</p>
  <p class="label" data-reveal="line">[ {{ site.location_country }} ]</p>
</section>
```

Replace `about.md` with (same wording as today; the intro and the three "What I build" items move into front matter):

```markdown
---
layout: about
title: About
permalink: /about/
intro: "Hi, I'm Gonzalo. I like solving infrastructure problems, and I'm most at home where the physical and the logical meet: the rack, the cabling, the switch config and the routing table that ties it all together."
skills:
  - title: Cisco labs
    text: "Multi-site enterprise networks with redundancy at every layer (BGP, HSRP, port-channels, spanning tree), VLAN segmentation, multi-area OSPF, DHCP relay, NAT and site-to-site and DMVPN tunnels secured with IPsec."
  - title: A small data center at home
    text: "A spine-leaf fabric of Cisco Catalyst switches with fiber and copper links, a structured and labeled patch panel, out-of-band access through a PiKVM and a serial console server, a UPS with safe shutdown, and runbooks for the failures I expect to hit. It's still being built, and I'll write about it here as it comes together."
  - title: Automation and cloud
    text: "I'm starting to manage my lab configs with Ansible from a RHEL machine, and this blog runs on AWS (S3 and CloudFront, set up with Terraform)."
---

## How I got here

Before IT, I managed customer service and guest relations at a 1,300-guest hotel in Berlin for 18 months. I handled the escalated cases, from overbookings to payment problems, and built the escalation process the team still uses. It taught me that a problem only goes away when you fix what caused it.

In 2025 I made the move into IT. I completed CCNA and CCNP Enterprise training, where most of the time was spent in the lab, and I'm studying Computer Engineering part-time at the Universitat Oberta de Catalunya alongside it.

## Why this blog

I write up everything I build: the problem, the design, the configuration, the tests and what broke along the way. It's part portfolio and part learning log. If you want to see how I think about networks, the posts are the best place to start.

I speak Spanish, English and German. If you want to talk about networking, data centers or an opportunity, you can reach me on [LinkedIn](https://www.linkedin.com/in/gonzalo-brandan/) or by [email](mailto:gonzalobrandan@outlook.de).
```

Create `404.html`:

```html
---
layout: default
title: Not found
permalink: /404.html
sitemap: false
---
<section class="not-found">
  <p class="label" data-reveal="line">[ 404 ]</p>
  <h1 class="page-title" data-reveal="line">This page doesn't exist.</h1>
  <p data-reveal="line">It may have moved when the site was redesigned. <a href="{{ '/' | relative_url }}">Go home</a> or browse the <a href="{{ '/archives/' | relative_url }}">Archive</a>.</p>
</section>
```

- [ ] **Step 5: Style About and 404**

Append to `_sass/_components.scss`:

```scss
// About

.visually-hidden {
  position: absolute;
  width: 1px;
  height: 1px;
  overflow: hidden;
  clip: rect(0 0 0 0);
  white-space: nowrap;
}

.about-hero {
  display: grid;
  gap: 1.5rem;
  padding: 14vh 0 8vh;
}

.about-hero__intro {
  max-width: 26ch;
  font-size: var(--fs-l);
  line-height: 1.05;
  letter-spacing: -0.035em;
}

.about-grid {
  display: grid;
  gap: 3rem var(--gutter);
  padding-bottom: 10vh;
}

.about-photo-frame {
  overflow: hidden;
  max-width: 520px;
  aspect-ratio: 4 / 5;
  border-radius: var(--radius);
}

.about-photo {
  width: 100%;
  height: 100%;
  object-fit: cover;
  will-change: transform;
}

@media (min-width: 900px) {
  .about-grid {
    grid-template-columns: repeat(12, minmax(0, 1fr));
  }

  .about-photo-frame {
    position: sticky;
    top: calc(var(--header-h) + 1rem);
    grid-column: 1 / span 4;
    align-self: start;
  }

  .about-body {
    grid-column: 6 / span 7;
  }
}

.skills {
  display: grid;
  gap: 3rem var(--gutter);
  padding-bottom: 10vh;
}

@media (min-width: 800px) {
  .skills {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

.skill {
  display: grid;
  align-content: start;
  gap: 1rem;
}

.skill__head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 1rem;
}

.skill__head h3 {
  font-size: var(--fs-l);
}

.skill__index {
  font-size: var(--fs-xxs);
  color: var(--color-muted);
}

.skill p {
  max-width: 40ch;
  color: var(--color-muted);
}

.location {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 1rem;
  padding: 6vh 0;
}

.location__title {
  font-size: var(--fs-xl);
  font-weight: 500;
  line-height: 0.9;
  letter-spacing: -0.055em;
}

// 404

.not-found {
  display: grid;
  gap: 1.5rem;
  padding: 18vh 0;
}

.not-found p {
  max-width: 40ch;
  font-size: var(--fs-m);
}
```

- [ ] **Step 6: Run the checks**

Run: `bash tools/check.sh`
Expected: PASS.

- [ ] **Step 7: Check in the browser**

Open <http://127.0.0.1:4000/about/>. Scrolling slowly zooms the photo out, and at 1440px the photo stays in view beside the text. The three numbered blocks sit side by side at 1440px and stacked at 375px. Open <http://127.0.0.1:4000/404.html>.

- [ ] **Step 8: Commit**

```bash
git add about.md 404.html _layouts/about.html _sass/_components.scss assets/js test
git commit -m "$(cat <<'EOF'
Redesign the About page and add a 404 page

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Search

Deliverable: `/search/` filters all posts as you type, keeps the query in the URL, and fails gracefully.

**Files:**
- Create: `search.json`, `search.html`, `assets/js/lib/search-core.js`, `assets/js/search.js`, `test/js/search.test.mjs`, `test/test_search.py`
- Modify: `_sass/_components.scss` (append), `assets/js/main.js`

**Interfaces:**
- Consumes: `run`; archive row classes from Task 5; `find`, `read_page`, `built_file`, `dated_post_count`.
- Produces: `normalize(value) -> string`, `searchPosts(posts, query) -> post[]` in `lib/search-core.js`; `initSearch(root = document)`; `search.json` entries `{title, url, date, topic, tags, text}`; hooks `[data-search]` (with `data-index`), `[data-search-input]`, `[data-search-status]`, `[data-search-results]`.

- [ ] **Step 1: Write the failing tests**

Create `test/js/search.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalize, searchPosts } from '../../assets/js/lib/search-core.js';

const posts = [
  { title: 'Configuring Secure DMVPN Tunnels', topic: 'Networking', tags: ['ipsec', 'dmvpn'], text: 'Spokes build GRE tunnels to the hub.' },
  { title: 'Creating a redundant network', topic: 'Networking', tags: ['BGP', 'HSRP'], text: 'Two ISPs and HSRP (hot standby).' },
  { title: 'Configure a Basic WLAN on the WLC', topic: 'Networking', tags: ['WLAN'], text: 'Wireless LAN controller setup with IPsec mentioned once.' },
];

test('empty and whitespace-only queries return nothing', () => {
  assert.deepEqual(searchPosts(posts, ''), []);
  assert.deepEqual(searchPosts(posts, '   \n '), []);
});

test('every word must match somewhere', () => {
  assert.deepEqual(searchPosts(posts, 'hsrp isps').map((p) => p.title), ['Creating a redundant network']);
  assert.deepEqual(searchPosts(posts, 'hsrp wlan'), []);
});

test('case-insensitive and accent-insensitive', () => {
  assert.equal(normalize('Configuración'), 'configuracion');
  assert.equal(searchPosts(posts, 'TÚNNELS').length, 1);
});

test('title and tag matches rank above body-only matches', () => {
  assert.deepEqual(searchPosts(posts, 'ipsec').map((p) => p.title), [
    'Configuring Secure DMVPN Tunnels',
    'Configure a Basic WLAN on the WLC',
  ]);
});

test('regex characters are treated as plain text', () => {
  assert.deepEqual(searchPosts(posts, '(hot').map((p) => p.title), ['Creating a redundant network']);
  assert.deepEqual(searchPosts(posts, '.*'), []);
});

test('tolerates missing fields', () => {
  assert.equal(searchPosts([{ title: 'Only a title' }], 'title').length, 1);
});
```

Create `test/test_search.py`:

```python
import json
import unittest

from helpers import built_file, dated_post_count, find, read_page


class SearchTest(unittest.TestCase):
    def test_index_has_every_post_with_plain_text(self):
        entries = json.loads(built_file("/search.json").read_text(encoding="utf-8"))
        self.assertEqual(len(entries), dated_post_count())
        for entry in entries:
            self.assertEqual(set(entry), {"title", "url", "date", "topic", "tags", "text"})
            self.assertNotIn("<p>", entry["text"])

    def test_search_page_has_the_form_and_a_no_js_fallback(self):
        html = read_page("/search/")
        self.assertTrue(find(html, "form", data_search="", data_index="/search.json"))
        self.assertTrue(find(html, "input", type="search", data_search_input=""))
        self.assertTrue(find(html, "p", data_search_status="", aria_live="polite"))
        self.assertIn("<noscript>", html)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `bash tools/check.sh`
Expected: FAIL — `SearchTest` failures and `Cannot find module .../lib/search-core.js`.

- [ ] **Step 3: Write the search logic**

Create `assets/js/lib/search-core.js`:

```js
// Search over the posts in search.json. Every word in the query must appear in the
// title, topic, tags or text (case- and accent-insensitive). Title and tag matches rank
// first; ties keep the original newest-first order.

export function normalize(value) {
  return String(value ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();
}

export function searchPosts(posts, query) {
  const words = normalize(query).split(/\s+/).filter(Boolean);
  if (words.length === 0) return [];

  const scored = [];
  for (const post of posts) {
    const title = normalize(post.title);
    const meta = normalize([post.topic, ...(post.tags ?? [])].join(' '));
    const text = normalize(post.text);
    const matchesAll = words.every((word) => title.includes(word) || meta.includes(word) || text.includes(word));
    if (!matchesAll) continue;
    const score = words.reduce(
      (sum, word) => sum + (title.includes(word) ? 3 : 0) + (meta.includes(word) ? 2 : 0),
      0,
    );
    scored.push({ post, score });
  }
  return scored.sort((a, b) => b.score - a.score).map((entry) => entry.post);
}
```

Create `assets/js/search.js`:

```js
// Search page: loads search.json once, filters as you type, keeps ?q= in the URL.

import { searchPosts } from './lib/search-core.js';

function rowFor(post) {
  const li = document.createElement('li');
  li.className = 'archive__row';
  const a = document.createElement('a');
  a.className = 'archive__link';
  a.href = post.url;
  const name = document.createElement('span');
  name.className = 'archive__name';
  name.textContent = post.title;
  const topic = document.createElement('span');
  topic.className = 'archive__topic';
  topic.textContent = post.topic ?? '';
  const date = document.createElement('span');
  date.className = 'archive__date';
  date.textContent = post.date ?? '';
  a.append(name, topic, date);
  const rule = document.createElement('hr');
  rule.className = 'rule';
  li.append(a, rule);
  return li;
}

export function initSearch(root = document) {
  const form = root.querySelector('[data-search]');
  if (!form) return;
  const input = form.querySelector('[data-search-input]');
  const status = root.querySelector('[data-search-status]');
  const results = root.querySelector('[data-search-results]');

  let postsPromise = null;
  const loadPosts = () => {
    postsPromise ??= fetch(form.dataset.index)
      .then((response) => {
        if (!response.ok) throw new Error(`search.json: HTTP ${response.status}`);
        return response.json();
      })
      .catch((error) => {
        postsPromise = null; // allow a retry on the next keystroke
        throw error;
      });
    return postsPromise;
  };

  const render = async () => {
    const query = input.value;
    const url = new URL(window.location.href);
    if (query.trim()) url.searchParams.set('q', query);
    else url.searchParams.delete('q');
    history.replaceState(history.state, '', url);

    if (!query.trim()) {
      results.replaceChildren();
      status.textContent = '';
      return;
    }

    let posts;
    try {
      posts = await loadPosts();
    } catch (error) {
      console.error('[site] search failed', error);
      status.textContent = 'Search is unavailable right now. You can browse every post in the Archive.';
      return;
    }
    if (input.value !== query) return; // a newer keystroke will render instead

    const matches = searchPosts(posts, query);
    results.replaceChildren(...matches.map(rowFor));
    status.textContent = matches.length
      ? `${matches.length} post${matches.length === 1 ? '' : 's'} found`
      : 'No posts match';
  };

  input.addEventListener('input', render);
  form.addEventListener('submit', (event) => {
    event.preventDefault();
    render();
  });

  input.value = new URLSearchParams(window.location.search).get('q') ?? '';
  if (input.value) render();
  input.focus();
}
```

Edit `assets/js/main.js`: add `import { initSearch } from './search.js';` to the imports and `run('search', () => initSearch());` at the bottom.

- [ ] **Step 4: Write the index and page**

Create `search.json`:

```liquid
---
layout: null
permalink: /search.json
sitemap: false
---
[
{% for post in site.posts %}
  {
    "title": {{ post.title | jsonify }},
    "url": {{ post.url | relative_url | jsonify }},
    "date": {{ post.date | date: '%b %Y' | jsonify }},
    "topic": {{ post.categories | first | capitalize | jsonify }},
    "tags": {{ post.tags | jsonify }},
    "text": {{ post.content | strip_html | normalize_whitespace | jsonify }}
  }{% unless forloop.last %},{% endunless %}
{% endfor %}
]
```

Create `search.html`:

```html
---
layout: page
title: Search
permalink: /search/
plain: true
---
<form class="search" role="search" data-search data-index="{{ '/search.json' | relative_url }}">
  <label class="label" for="search-input">[ Search posts ]</label>
  <input id="search-input" class="search__input" type="search" name="q" placeholder="OSPF, VPN, WLAN…" autocomplete="off" data-search-input>
</form>
<noscript><p class="search__status">Search needs JavaScript. You can browse every post in the <a href="{{ '/archives/' | relative_url }}">Archive</a>.</p></noscript>
<p class="search__status" data-search-status aria-live="polite"></p>
<ol class="archive__list" data-search-results></ol>
```

- [ ] **Step 5: Style search**

Append to `_sass/_components.scss`:

```scss
// Search

.search {
  display: grid;
  gap: 0.8rem;
  padding-bottom: 2rem;
}

.search__input {
  width: 100%;
  padding: 0.3em 0;
  border: 0;
  border-bottom: 1px solid var(--color-border);
  border-radius: 0;
  background: transparent;
  color: inherit;
  font: inherit;
  font-size: var(--fs-l);
  letter-spacing: -0.03em;
}

.search__input:focus-visible {
  outline: none;
  border-bottom-color: currentColor;
}

.search__status {
  min-height: 1.5em;
  padding-bottom: 1rem;
  font-size: var(--fs-xs);
  color: var(--color-muted);
}
```

- [ ] **Step 6: Run the checks**

Run: `bash tools/check.sh`
Expected: PASS.

- [ ] **Step 7: Check in the browser**

Open <http://127.0.0.1:4000/search/>: typing "ospf" lists the enterprise branch project; "xyzzy" shows "No posts match"; clearing the box clears the list; the URL shows `?q=ospf` and reloading keeps the results. In DevTools → Network, block `search.json` and type: the "unavailable" message appears and the page keeps working.

- [ ] **Step 8: Commit**

```bash
git add search.json search.html _sass/_components.scss assets/js test
git commit -m "$(cat <<'EOF'
Add site search

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Motion — loader, scroll reveals and page transitions

Deliverable: the once-per-session loader, reveal animations for every `data-reveal` element, fade page transitions, and reduced-motion support.

**Files:**
- Create: `_includes/loader.html`, `assets/js/loader.js`, `assets/js/reveal.js`, `assets/js/lib/transition-core.js`, `assets/js/transitions.js`, `test/js/transitions.test.mjs`, `test/js/reveal.test.mjs`, `test/test_motion.py`
- Modify: `_layouts/default.html`, `_sass/_animations.scss` (replace placeholder), `assets/js/main.js`

**Interfaces:**
- Consumes: `run`; `prefersReducedMotion`; the `is-loading` class and `loader-seen` session key set by `head.html` (Task 1); all `data-reveal` attributes from earlier tasks (`line`, `rule`, `image`, `grow`).
- Produces: `initLoader(root = document, { onStart } = {})`; `staggerDelays(count, step = 0.08, max = 0.6) -> number[]`, `initReveal(root = document)`, `revealAll(root = document)`; `shouldAnimateNavigation(link, event, location) -> boolean`; `initTransitions()`; classes on `<html>`: `is-loading`, `is-loaded`, `is-leaving`; class `is-visible` on revealed elements.

- [ ] **Step 1: Write the failing tests**

Create `test/js/transitions.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shouldAnimateNavigation } from '../../assets/js/lib/transition-core.js';

const location = { href: 'https://gonzalobrandan.com/about/', origin: 'https://gonzalobrandan.com', pathname: '/about/', search: '' };
const click = (overrides = {}) => ({ button: 0, metaKey: false, ctrlKey: false, shiftKey: false, altKey: false, defaultPrevented: false, ...overrides });
const link = (href, attrs = {}) => ({
  href: new URL(href, location.href).href,
  target: attrs.target ?? '',
  hasAttribute: (name) => name in attrs,
  getAttribute: (name) => attrs[name] ?? null,
});

test('animates a plain click on another internal page', () => {
  assert.equal(shouldAnimateNavigation(link('/archives/'), click(), location), true);
  assert.equal(shouldAnimateNavigation(link('/posts/Creating-a-redundant-network/'), click(), location), true);
});

test('leaves modified and non-primary clicks alone', () => {
  for (const key of ['metaKey', 'ctrlKey', 'shiftKey', 'altKey']) {
    assert.equal(shouldAnimateNavigation(link('/archives/'), click({ [key]: true }), location), false, key);
  }
  assert.equal(shouldAnimateNavigation(link('/archives/'), click({ button: 1 }), location), false);
  assert.equal(shouldAnimateNavigation(link('/archives/'), click({ defaultPrevented: true }), location), false);
});

test('leaves new-tab, download, external and mailto links alone', () => {
  assert.equal(shouldAnimateNavigation(link('/archives/', { target: '_blank' }), click(), location), false);
  assert.equal(shouldAnimateNavigation(link('/archives/', { download: '' }), click(), location), false);
  assert.equal(shouldAnimateNavigation(link('https://www.linkedin.com/in/gonzalo-brandan/'), click(), location), false);
  assert.equal(shouldAnimateNavigation(link('mailto:gonzalobrandan@outlook.de'), click(), location), false);
});

test('leaves same-page anchors and the current page alone', () => {
  assert.equal(shouldAnimateNavigation(link('#contact'), click(), location), false);
  assert.equal(shouldAnimateNavigation(link('/about/#how-i-got-here'), click(), location), false);
  assert.equal(shouldAnimateNavigation(link('/about/'), click(), location), false);
});

test('leaves file links alone', () => {
  assert.equal(shouldAnimateNavigation(link('/feed.xml'), click(), location), false);
  assert.equal(shouldAnimateNavigation(link('/assets/img/diagram.png'), click(), location), false);
});

test('handles a missing link', () => {
  assert.equal(shouldAnimateNavigation(null, click(), location), false);
});
```

Create `test/js/reveal.test.mjs`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { staggerDelays } from '../../assets/js/reveal.js';

test('staggers elements that appear together', () => {
  assert.deepEqual(staggerDelays(3), [0, 0.08, 0.16]);
});

test('caps the delay so long lists do not lag', () => {
  const delays = staggerDelays(20);
  assert.equal(delays.length, 20);
  assert.equal(Math.max(...delays), 0.6);
});

test('no elements, no delays', () => {
  assert.deepEqual(staggerDelays(0), []);
});
```

Create `test/test_motion.py`:

```python
import unittest

from helpers import find, read_page


class MotionTest(unittest.TestCase):
    def test_loader_markup_is_on_every_page(self):
        for path in ("/", "/about/", "/posts/Creating-a-redundant-network/"):
            with self.subTest(path=path):
                html = read_page(path)
                loaders = find(html, "div", cls="loader", data_loader="", aria_hidden="true")
                self.assertEqual(len(loaders), 1)

    def test_reveal_targets_exist(self):
        html = read_page("/")
        for kind in ("line", "rule", "image", "grow"):
            with self.subTest(kind=kind):
                self.assertTrue(find(html, data_reveal=kind))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to see them fail**

Run: `bash tools/check.sh`
Expected: FAIL — `MotionTest.test_loader_markup_is_on_every_page` and missing `transition-core.js` / `reveal.js` modules.

- [ ] **Step 3: Write the loader markup**

Create `_includes/loader.html`:

```html
<div class="loader" aria-hidden="true" data-loader>
  <span class="loader__count" data-loader-count>0%</span>
  <span class="loader__name">{{ site.author }}</span>
</div>
```

In `_layouts/default.html`, add `{% include loader.html %}` on the line directly after the skip link.

- [ ] **Step 4: Write the motion modules**

Create `assets/js/loader.js`:

```js
// First visit in a session: counts 0–100%, then lifts the panel away.
// head.html decides whether to show it (adds `is-loading` to <html>).

const COUNT_MS = 1400;
const LIFT_MS = 900;

export function initLoader(root = document, { onStart } = {}) {
  const html = document.documentElement;
  const loader = root.querySelector('[data-loader]');
  if (!loader || !html.classList.contains('is-loading')) {
    onStart?.();
    return;
  }

  const count = loader.querySelector('[data-loader-count]');
  const start = performance.now();

  const step = (now) => {
    const t = Math.min((now - start) / COUNT_MS, 1);
    const eased = 1 - (1 - t) ** 3;
    count.textContent = `${Math.round(eased * 100)}%`;
    if (t < 1) {
      requestAnimationFrame(step);
      return;
    }
    html.classList.add('is-loaded');
    onStart?.(); // reveal the page while the panel lifts
    setTimeout(() => html.classList.remove('is-loading', 'is-loaded'), LIFT_MS);
  };
  requestAnimationFrame(step);
}
```

Create `assets/js/reveal.js`:

```js
// Reveals [data-reveal] elements once as they scroll into view. Elements that
// appear together are staggered slightly.

import { prefersReducedMotion } from './lib/motion.js';

export function staggerDelays(count, step = 0.08, max = 0.6) {
  return Array.from({ length: count }, (_, index) => Math.min(Number((index * step).toFixed(3)), max));
}

export function revealAll(root = document) {
  root.querySelectorAll('[data-reveal]').forEach((element) => element.classList.add('is-visible'));
}

export function initReveal(root = document) {
  const items = [...root.querySelectorAll('[data-reveal]')];
  if (items.length === 0) return;
  if (prefersReducedMotion() || !('IntersectionObserver' in window)) {
    revealAll(root);
    return;
  }

  // threshold 0 and no negative margin, so the footer at the very bottom still reveals.
  const observer = new IntersectionObserver((entries) => {
    const entering = entries.filter((entry) => entry.isIntersecting).map((entry) => entry.target);
    staggerDelays(entering.length).forEach((delay, index) => {
      const element = entering[index];
      element.style.setProperty('--reveal-delay', `${delay}s`);
      element.classList.add('is-visible');
      observer.unobserve(element);
    });
  }, { threshold: 0 });

  items.forEach((element) => observer.observe(element));
}
```

Create `assets/js/lib/transition-core.js`:

```js
// Decides whether a link click gets the fade-out page transition. Anything that
// isn't a plain left click to another page on this site is left to the browser.

const FILE_LINK = /\.(xml|json|txt|pdf|png|jpe?g|gif|svg|webp|zip)$/i;

export function shouldAnimateNavigation(link, event, location) {
  if (!link || event.defaultPrevented) return false;
  if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return false;
  if (link.target && link.target !== '_self') return false;
  if (link.hasAttribute('download')) return false;

  let url;
  try {
    url = new URL(link.href, location.href);
  } catch {
    return false;
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return false;
  if (url.origin !== location.origin) return false;
  if (url.pathname === location.pathname && url.search === location.search) return false;
  if (FILE_LINK.test(url.pathname)) return false;
  return true;
}
```

Create `assets/js/transitions.js`:

```js
// Fade the page out on internal link clicks, then navigate normally.
// The next page fades in with CSS (see _animations.scss).

import { shouldAnimateNavigation } from './lib/transition-core.js';
import { prefersReducedMotion } from './lib/motion.js';

const LEAVE_MS = 450;

export function initTransitions() {
  if (prefersReducedMotion()) return;
  const html = document.documentElement;

  document.addEventListener('click', (event) => {
    const link = event.target instanceof Element ? event.target.closest('a[href]') : null;
    if (!shouldAnimateNavigation(link, event, window.location)) return;
    event.preventDefault();
    html.classList.add('is-leaving');
    setTimeout(() => {
      window.location.href = link.href;
    }, LEAVE_MS);
  });

  // Back/forward cache restores the page as it was: faded out. Undo that.
  window.addEventListener('pageshow', (event) => {
    if (event.persisted) html.classList.remove('is-leaving');
  });
}
```

Edit `assets/js/main.js`: add these imports

```js
import { initLoader } from './loader.js';
import { initReveal, revealAll } from './reveal.js';
import { initTransitions } from './transitions.js';
```

and append at the bottom:

```js
run('transitions', () => initTransitions());
run('loader', () => initLoader(document, {
  onStart: () => run('reveal', () => initReveal(), () => revealAll()),
}), () => {
  html.classList.remove('is-loading', 'is-loaded');
  run('reveal', () => initReveal(), () => revealAll());
});
```

- [ ] **Step 5: Write the animation styles**

Replace `_sass/_animations.scss` with:

```scss
// Starting states apply only with JS (html.js); head.html removes `js` if main.js never runs.

html.js [data-reveal="line"] {
  clip-path: inset(0 0 100% 0);
  transform: translateY(0.35em);
  transition:
    clip-path var(--dur-reveal) var(--ease-out) var(--reveal-delay, 0s),
    transform var(--dur-reveal) var(--ease-out) var(--reveal-delay, 0s);
}

html.js [data-reveal="line"].is-visible {
  clip-path: inset(-1em -1em -1em -1em);
  transform: none;
}

html.js [data-reveal="rule"] {
  transform: scaleX(0);
  transform-origin: left center;
  transition: transform 1.4s var(--ease-in-out) var(--reveal-delay, 0s);
}

html.js [data-reveal="rule"].is-visible {
  transform: scaleX(1);
}

html.js [data-reveal="image"] {
  opacity: 0;
  transform: translateY(2rem);
  transition:
    opacity 1.2s var(--ease-out) var(--reveal-delay, 0s),
    transform 1.2s var(--ease-out) var(--reveal-delay, 0s);
}

html.js [data-reveal="image"].is-visible {
  opacity: 1;
  transform: none;
}

html.js [data-reveal="grow"] {
  width: 0;
  margin-inline: 0;
  transition:
    width 1.3s var(--ease-in-out) calc(var(--reveal-delay, 0s) + 0.3s),
    margin 1.3s var(--ease-in-out) calc(var(--reveal-delay, 0s) + 0.3s);
}

html.js [data-reveal="grow"].is-visible {
  width: 1.6em;
  margin-inline: 0.12em;
}

// Loader

.loader {
  position: fixed;
  inset: 0;
  z-index: 90;
  display: none;
  align-items: flex-end;
  justify-content: space-between;
  padding: var(--gutter);
  background: var(--color-text);
  color: var(--color-bg);
  transition: transform 0.9s var(--ease-in-out);
}

html.is-loading {
  overflow: hidden;
}

html.is-loading .loader {
  display: flex;
}

html.is-loaded .loader {
  transform: translateY(-100%);
}

.loader__count {
  font-size: var(--fs-xl);
  font-variant-numeric: tabular-nums;
  line-height: 0.8;
  letter-spacing: -0.05em;
}

.loader__name {
  font-size: var(--fs-xs);
}

// Page transitions

@keyframes page-in {
  from {
    opacity: 0;
  }

  to {
    opacity: 1;
  }
}

html.js .site-main,
html.js .site-footer {
  animation: page-in 0.6s var(--ease-out) both;
}

html.is-leaving .site-main,
html.is-leaving .site-footer {
  opacity: 0;
  transition: opacity 0.45s var(--ease-in-out);
}

// Reduced motion: everything visible, nothing moves.

@media (prefers-reduced-motion: reduce) {
  html {
    scroll-behavior: auto;
  }

  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    transition-delay: 0s !important;
  }

  html.js [data-reveal] {
    clip-path: none;
    opacity: 1;
    transform: none;
  }

  html.js [data-reveal="grow"] {
    width: 1.6em;
    margin-inline: 0.12em;
  }
}
```

- [ ] **Step 6: Run the checks**

Run: `bash tools/check.sh`
Expected: PASS.

- [ ] **Step 7: Check in the browser (Review Focus 1 and 3)**

- Open a fresh private window at <http://127.0.0.1:4000/>: the counter runs 0→100% and the panel lifts, revealing the hero line by line. Reloading or visiting another page does not show the loader again in that window.
- Scroll the home page and Archive: headings slide up, rules draw left to right, cards fade up, and the footer at the very bottom reveals.
- Click Archive: the page fades out and the next one fades in. Then press Back: the previous page is fully visible, not faded.
- Ctrl/Cmd-click a post: it opens in a new tab and the current page does not fade. Click "Contact": it jumps to the footer without fading.
- DevTools → Rendering → "Emulate prefers-reduced-motion: reduce", then reload: no loader, everything visible immediately, no fades.
- Fail-safe: in DevTools → Network, block `main.js` and reload: after about 4 seconds all content is visible, with no loader stuck on screen.

- [ ] **Step 8: Commit**

```bash
git add _includes/loader.html _layouts/default.html _sass/_animations.scss assets/js test
git commit -m "$(cat <<'EOF'
Add the loader, scroll reveals and page transitions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Final verification

Deliverable: the branch passes the same checks CI runs, looks right on phone and desktop in both themes, and nothing from Chirpy is left.

**Files:**
- Modify: only files needed to fix problems found below.

**Interfaces:**
- Consumes: everything above.
- Produces: a branch ready for the user's review. No merge.

- [ ] **Step 1: Run every check, including html-proofer**

Run: `bash tools/check.sh --proof`
Expected: all Python and node tests pass, and html-proofer reports "HTML-Proofer finished successfully." Fix any broken link or image it reports, then re-run.

- [ ] **Step 2: Build the way the AWS deploy does**

```bash
echo 'url: "https://gonzalobrandan.com"' > _config.aws.yml
JEKYLL_ENV=production bundle exec jekyll build -d _site --config _config.yml,_config.aws.yml
grep -o '<link rel="canonical" href="[^"]*"' _site/index.html
rm _config.aws.yml
bash tools/check.sh
```

Expected: the canonical URL is `https://gonzalobrandan.com/` and the build prints no errors. (`_config.aws.yml` is gitignored; the last command rebuilds the normal site.)

- [ ] **Step 3: Look for Chirpy leftovers**

Run: `grep -rniE "chirpy|jekyll-theme|fa-(solid|brands|regular)|fas fa-" --include="*.html" --include="*.md" --include="*.yml" --include="*.scss" --include="*.js" . --exclude-dir={vendor,_site,node_modules,docs,.git}`
Expected: no matches. Remove anything it finds that belongs to Chirpy.

- [ ] **Step 4: Browser pass at phone and desktop widths, both themes**

With `bundle exec jekyll serve --livereload` running, check each of these pages at 375px and 1440px wide, in light and dark themes:

`/`, `/work/`, `/archives/`, `/posts/Creating-a-redundant-network/`, `/posts/configure-a-basic-wlan-on-the-wlc/`, `/about/`, `/tags/`, `/tags/cisco/`, `/search/?q=vpn`, `/404.html`

On each page, check that:
- in the DevTools console, `document.documentElement.scrollWidth <= innerWidth` is `true` (no sideways scroll). Also check this at 320px on `/` and on the redundant network post;
- text is readable in both themes and the diagrams are visible;
- Tab reaches the skip link first, and the focus outline is visible on links and buttons.

- [ ] **Step 5: Compare with the reference**

Open <https://matthieugivelet.com/> next to <http://127.0.0.1:4000/> at 1440px. Compare the type scale, spacing, the bracket labels, the rule animation, the list hover and the menu. Note any clear gaps for the user rather than copying code or assets from the reference.

- [ ] **Step 6: Commit any fixes**

```bash
git add -A -- . ':!_drafts'
git commit -m "$(cat <<'EOF'
Fix issues found in the final redesign check

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

(Skip if nothing changed.)

- [ ] **Step 7: Hand over**

Leave `bundle exec jekyll serve --livereload` running. Tell the user the branch is ready to review at <http://127.0.0.1:4000/>, and list any differences from the reference noted in Step 5. Do not merge into `main` or push.
