"""isolate.py - what serve.py's control origin must not answer: host_ok (a Host only a rebound DNS name sends), inside (a path that resolves outside the docroot), scriptable (a type that runs script when opened directly), and the headers every answer carries. Imported by path, imports nothing from serve.py.
Misses: a symlink swapped between inside() and the open; a symlink to a never-served file inside the docroot (_servable reads the URL, not the target); text/html that is not .html or .htm (.shtml) is not scriptable() here.
Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/isolate.py
"""
import ipaddress
import os
import re
from urllib.parse import urlsplit

COMMON = (("X-Content-Type-Options", "nosniff"), ("Referrer-Policy", "no-referrer"), ("X-DNS-Prefetch-Control", "off"))
XML_POLICY = "default-src 'none'; style-src 'unsafe-inline'; img-src data:; sandbox"
# Checked before urlsplit, which drops tabs and newlines and skips userinfo.
HOST_FORM = re.compile(r"(localhost|[0-9.]+|\[[0-9a-f:.]+\])(:[0-9]{1,5})?", re.I | re.A)


def host_ok(value):
    """True for localhost, an IPv4 or a bracketed IPv6 literal, with an optional port: the Hosts DNS rebinding cannot make a browser send."""
    if not HOST_FORM.fullmatch(value or ""):
        return False
    try:
        host = urlsplit("//" + value).hostname
        return host == "localhost" or ipaddress.ip_address(host).version == (6 if value[0] == "[" else 4)
    except ValueError:
        return False


def inside(root, path):
    """True when path, every symlink followed, is root or lies under it."""
    try:
        root, path = os.path.realpath(root), os.path.realpath(path)
    except ValueError:  # a NUL byte
        return False
    return path == root or path.startswith(os.path.join(root, ""))


def scriptable(ctype):
    """True for an XML type: a browser runs the script inside one opened as a document."""
    return ctype.split(";")[0].strip().lower().endswith(("/xml", "+xml"))
