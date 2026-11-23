#!/usr/bin/env python3
"""Check that every blob behind every tag in a Docker registry is present.

Usage: verify-registry.py [registry]   (default: localhost:5000)

Run it after cleaning up registry storage by hand and garbage-collecting.
A tag can look fine in the tag list while a child manifest or layer it needs
is gone, and that only shows up when a pod next pulls it. Index tags (BuildKit's
default) are followed into their child manifests. Exits 1 if anything is missing.
"""
import json
import sys
import urllib.error
import urllib.request

ACCEPT = ", ".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.docker.distribution.manifest.v2+json",
    "application/vnd.oci.image.manifest.v1+json",
])


def get(base, path, method="GET"):
    req = urllib.request.Request(f"{base}/{path}", method=method, headers={"Accept": ACCEPT})
    try:
        with urllib.request.urlopen(req) as res:
            return res.status, (res.read() if method == "GET" else b"")
    except urllib.error.HTTPError as err:
        return err.code, b""


def image_manifests(base, repo, ref):
    """Returns the image manifests behind ref, or None if any manifest is missing."""
    status, body = get(base, f"{repo}/manifests/{ref}")
    if status != 200:
        return None
    manifest = json.loads(body)
    if "layers" in manifest:
        return [manifest]
    children = [image_manifests(base, repo, c["digest"]) for c in manifest.get("manifests", [])]
    if any(c is None for c in children):
        return None
    return [m for c in children for m in c]


def check_tag(base, repo, tag):
    """Prints one line for the tag and returns how many things are missing."""
    manifests = image_manifests(base, repo, tag)
    if manifests is None:
        print(f"{repo}:{tag}  MISSING MANIFEST")
        return 1
    blobs = [b for m in manifests for b in [m["config"]["digest"], *(l["digest"] for l in m["layers"])]]
    missing = [b for b in blobs if get(base, f"{repo}/blobs/{b}", "HEAD")[0] != 200]
    print(f"{repo}:{tag}  {len(blobs) - len(missing)} present, {len(missing)} missing")
    return len(missing)


def main():
    base = f"http://{sys.argv[1] if len(sys.argv) > 1 else 'localhost:5000'}/v2"
    problems = 0
    for repo in json.loads(get(base, "_catalog")[1])["repositories"]:
        for tag in json.loads(get(base, f"{repo}/tags/list")[1])["tags"] or []:
            problems += check_tag(base, repo, tag)
    print("ALL OK" if problems == 0 else f"{problems} PROBLEMS")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
