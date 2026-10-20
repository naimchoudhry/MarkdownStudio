# Product Launch Plan

A one-page plan for launching **Lumen**, a habit-tracking app, in the spring. Everything here is *editable on either side* of Markdown Studio.

## Goals

1. Reach **10,000 sign-ups** in the first month.
2. Keep the crash-free rate above **99.5%**.
3. Ship the launch build by `April 14`.

## Timeline

| Phase | Dates | Owner | Status |
| :--- | :---: | :--- | :---: |
| Beta testing | Mar 3 – Mar 21 | Priya | Done |
| Marketing site | Mar 10 – Apr 4 | Sam | In progress |
| App Store review | Apr 7 – Apr 11 | Alex | Planned |
| Launch day | Apr 14 | Everyone | Planned |

## Launch checklist

- [x] Finalise pricing and the free trial
- [x] Record the App Store preview video
- [ ] Prepare press kit and screenshots
- [ ] Schedule launch-day announcements
  - Blog post
  - Newsletter
  - Social media

## Messaging

> Build better habits, one small step at a time.

Lead with the **streaks** feature, and keep the tone friendly and encouraging. See the [brand guide](https://example.com/brand) for colours and fonts.

## Release configuration

```swift
struct LaunchConfig {
    static let version = "1.0"
    static let trialDays = 14
    static let regions = ["US", "UK", "CA", "AU"]
}
```

## Risks

- **Review delays:** submit at least a week before launch day.
- **Server load:** scale up the sync servers on launch morning.
- **Support volume:** add two extra people to the support rota.

---

*Last updated by the launch team.*
