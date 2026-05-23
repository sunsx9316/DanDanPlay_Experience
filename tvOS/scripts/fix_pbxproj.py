#!/usr/bin/env python3
"""Fix XcodeGen-generated pbxproj: add missing `package` refs for local SPM deps.

Generic solution: auto-discovers all local SPM packages from XCLocalSwiftPackageReference
entries, parses each Package.swift to extract product names, and fills in missing
`package` fields in XCSwiftPackageProductDependency entries.
"""

import os
import re
import sys


def extract_products_from_package_swift(package_swift_path):
    """Parse a Package.swift and return a set of library product names."""
    try:
        with open(package_swift_path, "r") as f:
            content = f.read()
    except (FileNotFoundError, PermissionError):
        return set()

    products = set()

    # Match .library(name: "Xxx", ...) — handles single-line and multiline
    # Use a simplified state machine: find ".library(" then find "name:" within
    # the parentheses scope.
    for m in re.finditer(r'\.library\s*\(', content):
        start = m.start()
        # find the matching closing paren
        depth = 0
        i = m.end() - 1
        while i < len(content):
            if content[i] == "(":
                depth += 1
            elif content[i] == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        block = content[m.start() : i + 1]
        # extract name
        name_match = re.search(r'name\s*:\s*"([^"]+)"', block)
        if name_match:
            products.add(name_match.group(1))

    return products


def fix_pbxproj(path):
    with open(path, "r") as f:
        content = f.read()

    # Project directory (where the .xcodeproj lives)
    project_dir = os.path.dirname(os.path.dirname(os.path.abspath(path)))

    # 1. Find all XCLocalSwiftPackageReference: ID -> relative path
    local_pkg_refs = {}  # ref_id -> relative_path

    # Also validate these are local (not remote with file://)
    ref_blocks = list(re.finditer(
        r'(\w+) /\* XCLocalSwiftPackageReference "([^"]+)" \*/ = \{',
        content,
    ))
    for m in ref_blocks:
        ref_id, pkg_path = m.group(1), m.group(2)
        local_pkg_refs[ref_id] = pkg_path

    if not local_pkg_refs:
        print("  No local package references found.")
        return

    # 2. For each local package, find its products from Package.swift
    # path -> set of product names
    pkg_products = {}
    for rel_path in local_pkg_refs.values():
        abs_path = os.path.normpath(os.path.join(project_dir, rel_path))
        pkg_swift = os.path.join(abs_path, "Package.swift")
        products = extract_products_from_package_swift(pkg_swift)
        if products:
            pkg_products[rel_path] = products
            print(f"  Discovered {rel_path}: {products}")

    # Build reverse map: product_name -> package_path
    product_to_pkg = {}
    for pkg_path, products in pkg_products.items():
        for prod in products:
            product_to_pkg[prod] = pkg_path

    # 3. Find XCSwiftPackageProductDependency entries missing `package` field
    # Match each product dependency block
    dep_pattern = re.compile(
        r'(\w+) /\* ([^*]+) \*/ = \{\n'
        r'\s*isa = XCSwiftPackageProductDependency;\n'
        r'(\s*package = .*;\n)?'  # optional — we want ones WITHOUT this
        r'\s*productName = ([^;]+);'
    )

    modified = False
    for m in dep_pattern.finditer(content):
        dep_id = m.group(1)
        product_comment = m.group(2).strip()
        has_package = m.group(3) is not None
        product_name = m.group(4).strip()

        if has_package:
            continue  # already has package ref, skip

        # Find which package provides this product
        pkg_path = product_to_pkg.get(product_name)
        if not pkg_path:
            continue  # remote package or unknown, skip

        # Find the ref_id for this package path
        ref_id = None
        for rid, rpath in local_pkg_refs.items():
            if rpath == pkg_path:
                ref_id = rid
                break

        if not ref_id:
            continue

        # Insert package line
        old = m.group(0)
        new = re.sub(
            r'(isa = XCSwiftPackageProductDependency;\n)',
            rf'\1\t\t\tpackage = {ref_id} /* XCLocalSwiftPackageReference "{pkg_path}" */;\n',
            old,
        )
        content = content.replace(old, new)
        print(f"  ✓ {product_name} -> {pkg_path}")
        modified = True

    if not modified:
        print("  (all local package refs already correct)")

    with open(path, "w") as f:
        f.write(content)


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "AniXPlayer.xcodeproj/project.pbxproj"
    print(f"Fixing {path}...")
    fix_pbxproj(path)
    print("Done.")
