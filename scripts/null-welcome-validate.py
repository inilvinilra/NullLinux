#!/usr/bin/env python3
import argparse
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Missing dependency: python-yaml", file=sys.stderr)
    sys.exit(2)


def err(msg: str) -> None:
    print(f"[ERROR] {msg}", file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Null Welcome catalog")
    parser.add_argument(
        "--catalog",
        default="iso/airootfs/usr/share/null-welcome/catalog.yml",
        help="Path to catalog YAML",
    )
    args = parser.parse_args()

    catalog_path = Path(args.catalog)
    if not catalog_path.exists():
        err(f"Catalog not found: {catalog_path}")
        return 1

    with catalog_path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    if not isinstance(data, dict):
        err("Catalog root must be a mapping")
        return 1

    groups = data.get("groups")
    if not isinstance(groups, list) or not groups:
        err("Catalog must define a non-empty 'groups' list")
        return 1

    group_ids = set()
    item_keys = set()
    action_ids = set()
    package_values = set()
    issues = 0

    for idx, group in enumerate(groups):
        if not isinstance(group, dict):
            err(f"Group #{idx} must be an object")
            issues += 1
            continue

        gid = group.get("id")
        title = group.get("title")
        if not gid or not isinstance(gid, str):
            err(f"Group #{idx} missing string 'id'")
            issues += 1
            continue
        if gid in group_ids:
            err(f"Duplicate group id: {gid}")
            issues += 1
        group_ids.add(gid)

        if not title or not isinstance(title, str):
            err(f"Group '{gid}' missing string 'title'")
            issues += 1

        items = group.get("items", [])
        actions = group.get("actions", [])

        if items and actions:
            err(f"Group '{gid}' must not define both 'items' and 'actions'")
            issues += 1

        if items:
            if not isinstance(items, list):
                err(f"Group '{gid}' field 'items' must be a list")
                issues += 1
            else:
                for item in items:
                    if not isinstance(item, dict):
                        err(f"Group '{gid}' has a non-object item")
                        issues += 1
                        continue
                    name = item.get("name")
                    packages = item.get("packages")
                    if not name or not isinstance(name, str):
                        err(f"Group '{gid}' has item without string 'name'")
                        issues += 1
                        continue
                    key = (gid, name.lower())
                    if key in item_keys:
                        err(f"Duplicate item name in group '{gid}': {name}")
                        issues += 1
                    item_keys.add(key)
                    if not isinstance(packages, list) or not packages:
                        err(f"Item '{name}' in group '{gid}' must define non-empty 'packages'")
                        issues += 1
                        continue
                    for pkg in packages:
                        if not isinstance(pkg, str) or not pkg.strip():
                            err(f"Item '{name}' in group '{gid}' has invalid package value")
                            issues += 1
                            continue
                        value = pkg.strip()
                        if value in package_values:
                            continue
                        package_values.add(value)

        if actions:
            if not isinstance(actions, list):
                err(f"Group '{gid}' field 'actions' must be a list")
                issues += 1
            else:
                for action in actions:
                    if not isinstance(action, dict):
                        err(f"Group '{gid}' has a non-object action")
                        issues += 1
                        continue
                    aid = action.get("id")
                    label = action.get("label")
                    if not aid or not isinstance(aid, str):
                        err(f"Group '{gid}' has action without string 'id'")
                        issues += 1
                        continue
                    if aid in action_ids:
                        err(f"Duplicate action id: {aid}")
                        issues += 1
                    action_ids.add(aid)
                    if not label or not isinstance(label, str):
                        err(f"Action '{aid}' in group '{gid}' missing string 'label'")
                        issues += 1

    if issues:
        err(f"Validation failed with {issues} issue(s)")
        return 1

    print("Catalog validation passed.")
    print(f"Groups: {len(group_ids)}")
    print(f"Items: {len(item_keys)}")
    print(f"Unique packages: {len(package_values)}")
    print(f"Actions: {len(action_ids)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
