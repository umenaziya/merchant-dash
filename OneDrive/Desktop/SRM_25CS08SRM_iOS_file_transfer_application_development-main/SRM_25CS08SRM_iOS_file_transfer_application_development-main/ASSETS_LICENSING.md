# Asset Licensing and Permissions Documentation

## Avatar Images

### Asset Origin
The avatar images in `AwareShare/Resources/Assets.xcassets/` appear to be AI-generated images (based on filename patterns indicating ChatGPT generation). 

### Files Affected
- `3d avatar.imageset/` - Contains ChatGPT-generated image
- `3d avatar 1.imageset/` - Contains ChatGPT-generated image  
- `3d avatar 2.imageset/` - Contains ChatGPT-generated image (renamed to `avatar_3d_2.png`)
- `3d avatar 3.imageset/` - Contains ChatGPT-generated image (renamed to `avatar_3d_3.png`)
- `3d avatar 4.imageset/` - Contains ChatGPT-generated image
- `3d avatar 5.imageset/` - Contains ChatGPT-generated image

### Naming Convention Fix
**Fixed**: `3d avatar 2.imageset`
- **Original filename**: `ChatGPT Image Sep 10, 2025 at 05_49_57 PM.png` (violates iOS naming rules)
- **New filename**: `avatar_3d_2.png` (iOS-compliant: lowercase, underscore-separated)

**Fixed**: `3d avatar 3.imageset`
- **Original filename**: `ChatGPT Image Sep 10, 2025 at 05_37_17 PM.png` (violates iOS naming rules)
- **New filename**: `avatar_3d_3.png` (iOS-compliant: lowercase, underscore-separated)

### Licensing Status
⚠️ **ACTION REQUIRED**: Verify licensing and permissions for AI-generated images before committing:

1. **ChatGPT/OpenAI Terms**: If generated using ChatGPT/DALL-E, review OpenAI's Terms of Service:
   - Commercial use may require specific subscription tier
   - Attribution requirements may apply
   - Review current terms: https://openai.com/terms/

2. **Alternative Options**:
   - Use royalty-free stock images with commercial licenses
   - Generate new images with explicit commercial use permissions
   - Use original artwork with proper licensing

3. **Recommendation**: 
   - Document the source of each avatar image
   - Ensure compliance with AI service terms of service
   - Consider replacing with commercially licensed alternatives if needed

### Usage in Application
Avatar images are referenced in:
- `AwareShare/UI/Screens/Settings/EnhancedSettingsView.swift`
- `AwareShare/UI/Screens/Transfer/SwiftTransfer2UIView.swift`

These references use the asset catalog names (e.g., `"3d avatar 3"`), which are unchanged and continue to work correctly.

---

**Last Updated**: 2025-01-XX  
**Status**: Asset naming fixed, licensing verification pending

