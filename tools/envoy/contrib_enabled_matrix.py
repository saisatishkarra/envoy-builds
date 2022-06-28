#!/usr/bin/python

#todo:
# input contrib all extensions
# Read input for extensions that are needed using external file
# Filter extensions to remove any extensions that are part of needed and not available as part of envoy tag
# return disabled

# file in format CONTRIB_EXTENSIONS = {...}
exec(open('contrib/contrib_build_config.bzl').read())

enabled = [
    "envoy.filters.network.kafka_broker"
]

disabled = []
for k, v in CONTRIB_EXTENSIONS.items():
    disabled.append('--{target}:enabled={enabled}'.format(
        target=v.split(":")[0],
        enabled=(k in enabled))
    )

print(' '.join(disabled))
