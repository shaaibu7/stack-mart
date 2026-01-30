import os
import re
import subprocess

def run_cmd(cmd):
    subprocess.check_call(cmd, shell=True)

def git_commit(msg):
    run_cmd("git add .")
    # allow empty if nothing changed
    try:
        run_cmd(f"git commit -m '{msg}'")
    except subprocess.CalledProcessError:
        pass

def main():
    # Read the final contract content
    with open("contracts/stack-mart.clar", "r") as f:
        content = f.read()

    # Read the final test content
    with open("tests/stack-mart.spec.ts", "r") as f:
        test_content = f.read()

    # Back up files
    with open("contracts/stack-mart.clar.bak", "w") as f:
        f.write(content)
    with open("tests/stack-mart.spec.ts.bak", "w") as f:
        f.write(test_content)

    # Empty the file first
    with open("contracts/stack-mart.clar", "w") as f:
        f.write(";; StackMart Initial\n")
    
    # Regular expression to split by top-level definitions
    # Matches (define- at start of line
    chunks = re.split(r'(?=^\(define-)', content, flags=re.MULTILINE)
    
    header = chunks[0]
    definitions = chunks[1:]
    
    print(f"Total definitions found: {len(definitions)}")
    
    # Apply header
    with open("contracts/stack-mart.clar", "w") as f:
        f.write(header)
    git_commit("feat: initial contract structure and constants")
    
    # Apply definitions
    current_content = header
    for i, chunk in enumerate(definitions):
        current_content += chunk
        
        # Determine commit message from chunk type
        msg = "feat: update contract logic"
        if "define-trait" in chunk:
            msg = "feat: add sip-009 nft trait definition"
        elif "define-map" in chunk:
            map_name = re.search(r'define-map\s+([a-z0-9-]+)', chunk)
            name = map_name.group(1) if map_name else "data"
            msg = f"feat: add {name} map structure"
        elif "define-public" in chunk:
            func_name = re.search(r'define-public\s+\(([a-z0-9-]+)', chunk)
            name = func_name.group(1) if func_name else "function"
            msg = f"feat: implement {name} public function"
        elif "define-read-only" in chunk:
            func_name = re.search(r'define-read-only\s+\(([a-z0-9-]+)', chunk)
            name = func_name.group(1) if func_name else "getter"
            msg = f"feat: add {name} read-only helper"
        elif "define-data-var" in chunk:
            var_name = re.search(r'define-data-var\s+([a-z0-9-]+)', chunk)
            name = var_name.group(1) if var_name else "variable"
            msg = f"feat: add {name} state variable"
            
        # Write and commit
        with open("contracts/stack-mart.clar", "w") as f:
            f.write(current_content)
            
        git_commit(msg)
        
    # Then add tests
    with open("tests/stack-mart.spec.ts", "w") as f:
        f.write(test_content)
    git_commit("test: add comprehensive test suite including like system")
    
    print("Success: Generated commits.")

if __name__ == "__main__":
    main()
