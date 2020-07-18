+++
title = "No Referals [sic] Please"
date = "2018-08-28T05:23:17-00:00"
author = "alejandro"
tags = ["info-dump"]
draft = false
+++

### TL;DR

* Use `same-origin` Referrer Policy with Django
* Double leters are unecesary and slow down typing ([see Referer in this document](https://tools.ietf.org/html/rfc1945))

---

I found a post on Hacker News with a link to [webbkoll](https://webbkoll.dataskydd.net/en/) which tries to check how
privacy-friendly a particular site is. Of course I had to [check against my own
site](https://webbkoll.dataskydd.net/en/results?url=http%3A%2F%2Fkilonull.com%2F)!

Webbkoll reported that my referrers were being leaked and that I was using a Google as a third-party service. My site does make
requests to Google for some fonts, so that was expected. The privacy checker gave a helpful explanation on why someone might not
want to make requests to a third-party (well the actual description singled out Google specifically, but the same is true for any
third-party). I could host these fonts myself (as suggested) but the risk seems low to me and loading the fonts from Google means
that users are more likely to have the fonts already cached (making my site load faster... not that anyone reads this).

But, what's this referrer business? Turns out that browsers send information on what page a user comes from. This information is
stored in the headers under the `Referer` field. Yes, _referer_ and not _referrer_. According to wikipedia, [this
mispelling](https://tools.ietf.org/html/rfc1945) [is found](https://tools.ietf.org/html/rfc2616) in [multiple
RFCs](https://tools.ietf.org/html/rfc7231).

This information seems pretty innocuous, but can be used (in tandem with other techniques) to track people online. Sites can
associate its users with their referring pages. Webbkoll provides a good example:

_Let's say you're logged in on Facebook. You visit a page with the URL http://www.some-hospital.com/some-medical-condition. On
that page, you click a link to their Facebook page. Your browser then sends Referer:
http://www.some-hospital.com/some-medical-condition to facebook.com, along with your Facebook cookies, allowing Facebook to
associate your identity with that particular page._

Luckily for us tinfoil hat folk, there is a [Referrer Policy](https://www.w3.org/TR/referrer-policy/) (_referrer_ spelled
correctly this time) and a [helpful MDN page](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referrer-Policy). I was
excited to stick it to the surveillance state and quickly fired up my terminal and SSH'd into my server to update my NGINX
configuration with `add_header Referrer-Policy "no-referrer";`. I checked afterward and sure enough my browser did not send a
referer! I had chores I wanted to avoid so I frantically logged in to make a post... but I was greeted with this:

> Forbidden (403)
>
> CSRF verification failed. Request aborted.
>
> You are seeing this message because this HTTPS site requires a 'Referer header' to be sent by your Web browser, but none was sent. This header is required for security reasons, to ensure that your browser is not being hijacked by third parties.
>
> If you have configured your browser to disable 'Referer' headers, please re-enable them, at least for this site, or for HTTPS connections, or for 'same-origin' requests.
>
> If you are using the &lt;meta name="referrer" content="no-referrer"&gt; tag or including the 'Referrer-Policy: no-referrer' header, please remove them. The CSRF protection requires the 'Referer' header to do strict referer checking. If you're concerned about privacy, use alternatives like &lt;a rel="noreferrer" ...&gt; for links to third-party sites.
>
> More information is available with DEBUG=True.

Apparently Django has an extra security measure for HTTPS pages ([see step
4](https://docs.djangoproject.com/en/2.1/ref/csrf/#how-it-works)). In short, the `Referer` header is used to make sure that a
request comes from the same site. zinfandel has a [better explanation](https://security.stackexchange.com/a/96139) on Stack
Overflow. Bummer. But this can be worked around by using the `same-origin` policy instead of `no-referrer`.
