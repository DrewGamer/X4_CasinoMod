"""
Script to extract vanilla X4 XML, Lua, and MD script files from game catalogs into references/vanilla.
"""
import os
import sys
import json
from pathlib import Path

def extract_cat(cat_path, dat_path, target_dir, filter_prefixes=None):
    if not os.path.exists(cat_path) or not os.path.exists(dat_path):
        return 0
    
    extracted_count = 0
    with open(cat_path, 'r', encoding='utf-8', errors='ignore') as cat_f, \
         open(dat_path, 'rb') as dat_f:
        
        for line in cat_f:
            line = line.strip()
            if not line:
                continue
            parts = line.rsplit(' ', 3)
            if len(parts) < 4:
                continue
            
            rel_path, size_str, timestamp_str, hash_str = parts
            rel_path = rel_path.replace('\\', '/')
            try:
                size = int(size_str)
            except ValueError:
                continue
            
            # Check filter
            should_extract = False
            if filter_prefixes:
                for prefix in filter_prefixes:
                    if rel_path.lower().startswith(prefix.lower()) or rel_path.lower().endswith('.html') or rel_path.lower().endswith('.xsd'):
                        should_extract = True
                        break
            else:
                should_extract = True
            
            if should_extract:
                dest_path = os.path.join(target_dir, rel_path)
                os.makedirs(os.path.dirname(dest_path), exist_ok=True)
                data = dat_f.read(size)
                with open(dest_path, 'wb') as out_f:
                    out_f.write(data)
                extracted_count += 1
            else:
                dat_f.seek(size, os.SEEK_CUR)
                
    return extracted_count

def main():
    workspace = Path(__file__).resolve().parent.parent
    config_file = workspace / "config.local.json"
    
    if not config_file.exists():
        print(f"Error: {config_file} not found.")
        sys.exit(1)
        
    with open(config_file, "r") as f:
        config = json.load(f)
        
    x4_dir = config.get("x4_install_path")
    if not x4_dir or not os.path.exists(x4_dir):
        print(f"Error: X4 installation path not found: {x4_dir}")
        sys.exit(1)
        
    target_dir = workspace / "references" / "vanilla"
    os.makedirs(target_dir, exist_ok=True)
    
    filter_prefixes = [
        "md/",
        "libraries/",
        "t/",
        "aiscripts/",
        "ui/"
    ]
    
    print(f"[*] Extracting vanilla script references from: {x4_dir}")
    print(f"[*] Target destination: {target_dir}")
    
    # 1. Base Game Catalogs (01 to 09, subst_01, etc.)
    cat_files = sorted([f for f in os.listdir(x4_dir) if f.endswith(".cat") and not f.endswith("_sig.cat")])
    total_extracted = 0
    for cat in cat_files:
        dat = cat[:-4] + ".dat"
        cat_path = os.path.join(x4_dir, cat)
        dat_path = os.path.join(x4_dir, dat)
        if os.path.exists(dat_path):
            count = extract_cat(cat_path, dat_path, str(target_dir), filter_prefixes)
            print(f"  [+] {cat}: extracted {count} files")
            total_extracted += count
            
    # 2. DLC Catalogs in extensions/
    ext_dir = os.path.join(x4_dir, "extensions")
    if os.path.exists(ext_dir):
        dlcs = ["ego_dlc_split", "ego_dlc_terran", "ego_dlc_pirate", "ego_dlc_boron", "ego_dlc_timelines"]
        for dlc in dlcs:
            dlc_path = os.path.join(ext_dir, dlc)
            if os.path.exists(dlc_path):
                dlc_cats = sorted([f for f in os.listdir(dlc_path) if f.endswith(".cat") and not f.endswith("_sig.cat")])
                for cat in dlc_cats:
                    dat = cat[:-4] + ".dat"
                    cat_path = os.path.join(dlc_path, cat)
                    dat_path = os.path.join(dlc_path, dat)
                    if os.path.exists(dat_path):
                        count = extract_cat(cat_path, dat_path, str(target_dir), filter_prefixes)
                        print(f"  [+] {dlc}/{cat}: extracted {count} files")
                        total_extracted += count
                        
    print(f"\n[+] Extraction complete! Total script reference files extracted: {total_extracted}")

if __name__ == "__main__":
    main()
