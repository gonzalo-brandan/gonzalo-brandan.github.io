# gonzalo-brandan.github.io

Source for my technical blog, where I write up networking labs and notes on
Cisco technologies (routing, switching, wireless, VPNs) as I work toward the
CCNP certification. Built with [Jekyll](https://jekyllrb.com/) and the
[Chirpy](https://github.com/cotes2020/jekyll-theme-chirpy) theme, deployed to
GitHub Pages via GitHub Actions on every push to `main`.

Live site: <https://gonzalo-brandan.github.io>

## Local development

```shell
bundle install
bundle exec jekyll serve
```

or, using the helper script:

```shell
bash tools/run.sh
```

Posts live in `_posts/`, images in `assets/img/`.

## License

The site content is mine; the underlying Chirpy theme is published under the
[MIT License][mit].

[mit]: https://github.com/cotes2020/chirpy-starter/blob/master/LICENSE
