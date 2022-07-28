#!/usr/bin/env python

#todo:
# input contrib all extensions
# Read input for extensions that are needed using external file
# Filter extensions to remove any extensions that are part of needed and not available as part of envoy tag
# return disabled

import os

# file in format CONTRIB_EXTENSIONS = {...}
exec(open(os.environ['ENVOY_SOURCE_DIR']+'/contrib/contrib_build_config.bzl').read())
exec(open(os.environ['ENVOY_SOURCE_DIR']+'/sources/extensions/extensions_build_config.bzl').read())

# By default all contrib are disabled. Use whitelisting to enable
enable_contrib_extensions = [
    "envoy.filters.network.kafka_broker"
]

# By default all source extensions are enabled. Use blacklisting to disable
disable_source_extensions = [
    "envoy.filters.http.file_system_buffer"
    "envoy.transport_sockets.tcp_stats"
    
]

# Filtered list of extensions to be whitelisted / blacklisted per envoy tag
desired = []

for k, v in CONTRIB_EXTENSIONS.items():
    desired.append('--{target}:enabled={isEnabled}'.format(
        target=v.split(":")[0],
        isEnabled=(k in enable_contrib_extensions))
    )

for k, v in EXTENSIONS.items():
    desired.append('--{target}:enabled={isDisabled}'.format(
        target=v.split(":")[0],
        isDisabled=(k in disable_source_extensions))
    )

print(' '.join(desired))
