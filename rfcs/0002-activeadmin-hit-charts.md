# RFC 0002: ActiveAdmin hit charts

- Type: Standards Track
- Status: Draft
- Created: 2026-11-12
- Author: Codex

## Summary

Add an included enabled/disabled evaluation chart to each ActiveAdmin Features
detail page, with bounded history windows and a replaceable chart partial.

## Motivation

The detail page currently exposes hourly counts only as a table. Operators need
to compare evaluation volume and enabled share across time without building an
application-specific dashboard.

## Guide-level explanation

Open a feature and select Last 24 hours, Last 7 days, or Last 30 days. The page
shows enabled and disabled counts, enabled share, and a two-series line chart.
Expand the data table for exact values. No JavaScript setup is required.

To customize the chart, add `app/views/admin/features/_chart.html.erb` to the host
application. It receives a `chart` local. The surrounding controls, totals, and
table remain supplied by Onni. The host can replace `_stats.html.erb` for the
whole statistics section instead.

## Reference-level explanation

The existing feature GET action accepts `range=24h`, `range=7d`, or `range=30d`.
Omitting range selects 24h. Unsupported values, arrays, and objects return HTTP
400. Dashboard authorization applies before reading statistics.

Windows include the current UTC hour or day, which is incomplete. The 24h view
has 24 hourly points. The 7d and 30d views have 7 and 30 daily points. The query
starts at the first displayed UTC period and ends at the request's current time,
reading at most 720 stored hourly buckets under the existing uniqueness contract
with ActiveRecord. The memory adapter retains its existing scan of stored history.
No per-point queries or writes occur. Aggregation is linear in returned buckets.

The chart orders points and fills absent periods with zero recorded evaluations.
Both series share a zero-based scale. Enabled uses a solid blue line; disabled
uses a dashed orange line. A textual legend, accessible image name, description,
and expandable table accompany the chart. Empty history shows a no-data message.

Totals sum the displayed periods. Enabled share is enabled / (enabled + disabled)
times 100, or no data when the denominator is zero. The page identifies counts
as evaluations rather than unique users and warns that sampling can affect them.
Current sampling configuration cannot establish historical sampling rates.
No per-variant exposure, conversion, or significance claims are made.

The `chart` local is an `Onni::HitChart`. Its readers are `range`, `from`, `to`,
`rows`, `enabled_hits`, and `disabled_hits`. Methods `hourly?`, `enabled_percentage`,
`maximum`, and `points(column)` support rendering. Rows contain UTC `period_start`,
`enabled_hits`, and `disabled_hits`. Points support `enabled_hits` and
`disabled_hits` on an SVG plot from (56, 24) to (776, 208).

## Security considerations

Range selection is allowlisted before queries. Chart text is escaped by Rails.
No evaluation identities, actor identifiers, or new public endpoints are added.

## Drawbacks

Daily aggregation hides within-day peaks in longer windows. Sampling and removed
history limit interpretation. A static SVG has no interactive tooltips.

## Rationale and alternatives

Server-rendered SVG and the existing statistics query avoid new runtime packages
and host asset configuration. A JavaScript chart library is unnecessary for two
bounded series. Keeping only the table leaves comparison difficult.

## Prior art

The existing Features detail table already consumes `Onni::Stats.for`; the chart
uses those same enabled/disabled counters.

## Unresolved questions

The host application's final ActiveAdmin theme still needs visual review.
