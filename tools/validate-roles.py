#!/usr/bin/env python3
"""Validate Null Linux role manifests against the role schema."""

from __future__ import annotations

import glob
import re
import sys

import yaml

ROLE_ID = re.compile(r"^[a-z][a-z0-9-]*$")
PKG_NAME = re.compile(r"^[a-z0-9][a-z0-9@._+-]*$")
REQUIRED = ("id", "name", "description", "menu_name", "menu_icon", "packages")


def main() -> int:
    errors: list[str] = []
    seen: dict[str, list[str]] = {}
    roles = sorted(glob.glob("config/roles/*.yml"))

    if not roles:
        print("no role manifests found under config/roles/")
        return 1

    for path in roles:
        role = path.split("/")[-1][: -len(".yml")]
        if not ROLE_ID.match(role):
            errors.append(f"{path}: role id must be lowercase kebab-case")

        try:
            data = yaml.safe_load(open(path, encoding="utf-8"))
        except yaml.YAMLError as exc:
            errors.append(f"{path}: invalid YAML: {exc}")
            continue

        if not isinstance(data, dict):
            errors.append(f"{path}: top level must be a mapping")
            continue

        for key in REQUIRED:
            if not data.get(key):
                errors.append(f"{path}: missing required field '{key}'")

        if data.get("id") not in (None, role):
            errors.append(f"{path}: id '{data.get('id')}' does not match filename")

        packages = data.get("packages")
        if not isinstance(packages, list):
            continue

        local_seen = set()
        for pkg in packages:
            if not isinstance(pkg, str) or not PKG_NAME.match(pkg):
                errors.append(f"{path}: invalid package name {pkg!r}")
                continue
            if pkg in local_seen:
                errors.append(f"{path}: duplicate package '{pkg}' within role")
            local_seen.add(pkg)
            seen.setdefault(pkg, []).append(role)

    shared = {p: r for p, r in seen.items() if len(r) > 1}

    if errors:
        print("\n".join(errors))
        return 1

    print(
        f"{len(roles)} roles, {sum(len(v) for v in seen.values())} entries, "
        f"{len(seen)} unique packages, {len(shared)} shared across roles"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
