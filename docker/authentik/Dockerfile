# Authentik for Swarmex
# Base: 2024.8.3 with fixes for Attr dataclass path navigation
# Fixes: config.py update()/get()/refresh()/get_keys() + dict.py unwrap Attr
# Deps: PostgreSQL 18 + Valkey 8
FROM ghcr.io/goauthentik/server:2024.8.3
COPY patches/config.py /authentik/lib/config.py
COPY patches/dict.py /authentik/lib/utils/dict.py
