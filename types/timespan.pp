# lint:ignore:140chars

# @summary A systemd time span
#
# Accepts one or more numbers, each followed by a systemd time unit (for example
# '12h', '10min', '1.5h' or '1min 30s'). A bare number means seconds. A value of
# '0' means no limit.
type Pe_databases::Timespan = Pattern[/\A([0-9]+(\.[0-9]+)?[ ]*(us|usec|ms|msec|s|sec|seconds|second|min|minutes|minute|m|hours|hour|hr|h|days|day|d|weeks|week|w|months|month|years|year|y)[ ]*)*[0-9]+(\.[0-9]+)?([ ]*(us|usec|ms|msec|s|sec|seconds|second|min|minutes|minute|m|hours|hour|hr|h|days|day|d|weeks|week|w|months|month|years|year|y))?\z/]
# lint:endignore
