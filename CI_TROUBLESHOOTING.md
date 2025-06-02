# CI/CD Troubleshooting Guide

## 🚨 Common CI Failures and Solutions

### 1. Build Failures

#### Issue: `sozo build` fails with "command not found"
**Solution:** The CI workflow now handles this automatically by falling back to `scarb build --ignore-cairo-version`

#### Issue: Cairo version mismatch
**Error:** `the required Cairo version of package coa is not compatible with current version`
**Solution:** 
- CI automatically uses `--ignore-cairo-version` flag
- For local development: `scarb build --ignore-cairo-version`

#### Issue: Missing newlines at end of files
**Error:** `\ No newline at end of file`
**Solution:**
```bash
# Fix all missing newlines automatically
find . -type f \( -name "*.cairo" -o -name "*.toml" \) -exec sh -c 'if [ "$(tail -c1 "$1" | wc -l)" -eq 0 ]; then echo >> "$1"; echo "Added newline to $1"; fi' _ {} \;
```

### 2. Test Failures

#### Issue: ERC1155 tests fail
**Check:**
1. Navigate to `erc1155/` directory
2. Run `snforge test` locally
3. Check test dependencies in `erc1155/Scarb.toml`

#### Issue: Dojo tests fail or not found
**Note:** This is expected if no dojo tests are written yet. The CI will show a warning but won't fail.

### 3. Formatting Issues

#### Issue: Code formatting check fails
**Solution:**
```bash
# Format main project
scarb fmt --ignore-cairo-version

# Format ERC1155 contracts
cd erc1155
scarb fmt
cd ..
```

### 4. asdf Plugin Errors

#### Issue: "Broken pipe during printf" or plugin installation fails
**Solution:** CI workflow now includes fallback handling:
- Plugins are installed with `|| echo "Plugin already exists"`
- Installation is verified with version checks

## 🔧 Local Testing

### Run Local CI Pipeline
```bash
# Run the same checks as CI locally
./scripts/local-ci.sh
```

### Individual Commands
```bash
# Check for missing newlines
find . -type f \( -name "*.cairo" -o -name "*.toml" \) -exec sh -c 'if [ "$(tail -c1 "$1" | wc -l)" -eq 0 ]; then echo "Missing newline in $1"; exit 1; fi' _ {} \;

# Build main project
scarb build --ignore-cairo-version

# Build ERC1155
cd erc1155 && scarb build && cd ..

# Run ERC1155 tests
cd erc1155 && snforge test && cd ..

# Check formatting
scarb fmt --check --ignore-cairo-version
cd erc1155 && scarb fmt --check && cd ..
```

## 📋 CI Workflow Overview

The CI pipeline performs these steps:

1. **Environment Setup**
   - Install Rust, asdf, Scarb, Dojo, Starknet Foundry
   - Verify installations

2. **Code Quality Checks**
   - Check for missing newlines
   - Validate configuration files exist

3. **Build Process**
   - Build main dojo contracts (with Cairo version handling)
   - Build ERC1155 contracts

4. **Testing**
   - Run ERC1155 tests with snforge
   - Attempt dojo tests (if available)

5. **Formatting Validation**
   - Check main project formatting
   - Check ERC1155 formatting

## 🛠️ Quick Fixes

### Before Committing
```bash
# Run this to ensure CI will pass
./scripts/local-ci.sh
```

### If CI Fails
1. Check the specific step that failed in GitHub Actions
2. Run the corresponding local command from this guide
3. Fix any issues locally
4. Commit and push the fixes

## 📦 Dependencies and Versions

- **Cairo:** 2.10.1 (with ignore-cairo-version for compatibility)
- **Scarb:** 2.10.1
- **Dojo:** 1.5.0
- **Starknet Foundry:** 0.35.0

## 🔍 Debugging Tips

1. **Check logs carefully:** GitHub Actions provides detailed logs for each step
2. **Test locally first:** Use `./scripts/local-ci.sh` before pushing
3. **Version compatibility:** If you encounter version issues, check if tools need updating
4. **File permissions:** Ensure shell scripts are executable (`chmod +x`)

## 📞 Getting Help

If CI continues to fail after following this guide:

1. Check the specific error message in GitHub Actions logs
2. Compare local environment with CI requirements
3. Verify all files have proper newlines and formatting
4. Ensure all dependencies are correctly specified in `Scarb.toml` files

## ✅ Success Indicators

When CI passes, you should see:
- ✅ Main dojo contracts built successfully
- ✅ ERC1155 contracts built successfully
- ✅ ERC1155 tests passed
- ✅ Formatting checks passed
- ✅ Configuration validation passed 