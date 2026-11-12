# ActiveAdmin Features scan-friendly UI

## Participants

Andrei Makarov.

## Decisions

Show one Enable or Disable action from current global state. Show expiry as days or years with the full date in the title hint. Drop explainer panels and nested panel chrome on the Features index. Keep hit storage as compact metrics and only surface past-retention or large-table status tags. Shorten feature show hit copy.

## Effects

Index and show templates no longer render authorization or migration explainers. Gates column lists gate keys only. Hit charts keep totals and the SVG; long sampling and UTC prose is removed.

## Next

Publish onni 0.1.2 and bump host apps.

## Source

app/admin/features.rb
app/views/admin/features/show.html.erb
app/views/admin/features/_stats.html.erb
app/views/admin/features/_chart.html.erb
lib/onni/flag.rb
