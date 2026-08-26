#!/usr/bin/env python3
"""
XML and Schema Validator for X4 Foundations Modding.
Validates content.xml, Mission Director scripts (md/*.xml), and text databases (t/*.xml)
against Egosoft XSD schemas and XML syntax rules.
"""

import sys
import os
import glob
from pathlib import Path

try:
    from lxml import etree
    import xmlschema
except ImportError:
    print("Error: Required validation libraries 'lxml' and 'xmlschema' not found in Python environment.")
    print("Run: pip install lxml xmlschema")
    sys.exit(1)


def validate_xml_syntax(file_path: Path) -> tuple[bool, str]:
    """Check if XML file is well-formed."""
    try:
        parser = etree.XMLParser(recover=False)
        etree.parse(str(file_path), parser)
        return True, "Well-formed"
    except etree.XMLSyntaxError as err:
        return False, f"Syntax Error: {err}"


def validate_against_schema(file_path: Path, schema_path: Path) -> tuple[bool, str]:
    """Validate XML against an XSD schema if available."""
    if not schema_path.exists():
        return True, f"Schema {schema_path.name} not found, skipping schema check"
    
    try:
        schema = xmlschema.XMLSchema(str(schema_path))
        schema.validate(str(file_path))
        return True, f"Valid against {schema_path.name}"
    except xmlschema.XMLSchemaValidationError as err:
        return False, f"Schema Validation Error ({schema_path.name}): {err.message} (Line {err.sourceline})"
    except Exception as err:
        return False, f"Validation Error ({schema_path.name}): {err}"


def main() -> int:
    workspace_root = Path(__file__).resolve().parent.parent
    schemas_dir = workspace_root / "schemas"
    
    print("=" * 60)
    print("X4 Casino Mod - XML Validation Suite")
    print(f"Workspace: {workspace_root}")
    print("=" * 60)

    files_to_validate: list[tuple[Path, Path | None]] = []

    # 1. content.xml
    content_xml = workspace_root / "content.xml"
    if content_xml.exists():
        files_to_validate.append((content_xml, schemas_dir / "content.xsd"))

    # 2. md/*.xml
    for md_file in (workspace_root / "md").glob("*.xml"):
        files_to_validate.append((md_file, schemas_dir / "md.xsd"))

    # 3. t/*.xml
    for t_file in (workspace_root / "t").glob("*.xml"):
        files_to_validate.append((t_file, schemas_dir / "libraries.xsd"))

    # 4. ui/**/*.xml
    for ui_file in (workspace_root / "ui").glob("**/*.xml"):
        files_to_validate.append((ui_file, None))

    if not files_to_validate:
        print("[!] No XML files found to validate yet.")
        return 0

    errors_count = 0
    passed_count = 0

    for xml_file, schema_path in files_to_validate:
        rel_path = xml_file.relative_to(workspace_root)
        print(f"Validating: {rel_path} ...", end=" ")

        # Step 1: Syntax check
        syntax_ok, syntax_msg = validate_xml_syntax(xml_file)
        if not syntax_ok:
            print(f"[FAIL]\n  {syntax_msg}")
            errors_count += 1
            continue

        # Step 2: Schema check (if schema assigned)
        if schema_path and schema_path.exists():
            schema_ok, schema_msg = validate_against_schema(xml_file, schema_path)
            if not schema_ok:
                print(f"[FAIL]\n  {schema_msg}")
                errors_count += 1
                continue
            else:
                print(f"[PASS] ({schema_path.name})")
                passed_count += 1
        else:
            print("[PASS] (Syntax Valid)")
            passed_count += 1

    print("-" * 60)
    print(f"Results: {passed_count} passed, {errors_count} failed.")
    print("=" * 60)

    return 1 if errors_count > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
