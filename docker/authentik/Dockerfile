# Authentik patched for Swarmex
# Fixes defusedxml 'Attr' object does not support item assignment
# The issue is defusedxml >= 0.8.0 changed Attr to be immutable
# Fix: pin defusedxml to last working version

FROM ghcr.io/goauthentik/server:2024.8.3

USER root
RUN pip install --no-cache-dir 'defusedxml==0.7.1' --force-reinstall
USER 1000
