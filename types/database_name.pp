# @summary A PostgreSQL database name
#
# Accepts a string made of letters, digits, underscores and hyphens that does
# not start with a hyphen (for example 'pe-puppetdb').
type Pe_databases::Database_name = Pattern[/\A[A-Za-z0-9_][A-Za-z0-9_-]*\z/]
