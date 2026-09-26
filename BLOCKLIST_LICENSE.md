# The blocklist is licensed separately

Everything in this repository is under the Mozilla Public License 2.0
(see `LICENSE`) **except these three files**:

| File | What it is |
|---|---|
| `blocklist.csv` | 4,000 gambling domains with a `source` column |
| `gambling_domains.txt` | The same 4,000 domains, one per line |
| `supabase/seed_blocklist.sql` | The same list as SQL inserts |

3,833 of the 4,000 domains (the rows marked `hagezi`) come from the
gambling list in [HaGeZi's DNS Blocklists](https://github.com/hagezi/dns-blocklists),
which is published under the
[GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).
Those rows stay under GPL-3.0 here, with credit to HaGeZi.

The other 167 rows (marked `pawl-curated`) were written for Pawl and you may
use them under the MPL like the rest of the project.

The Swift and SQL code that *loads* a blocklist does not contain the list and
is MPL. The app downloads the list at run time from its own database.
