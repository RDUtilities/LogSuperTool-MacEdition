#!/usr/bin/env python3
"""
Generates LogSuperToolMacEdition.xcodeproj/project.pbxproj
Modelled on a real Xcode 16.3 project (objectVersion = 77).
"""

import os, json, hashlib

ROOT         = os.path.dirname(os.path.abspath(__file__))
PROJ_NAME    = "LogSuperToolMacEdition"
BUNDLE_ID    = "com.rdutilities.LogSuperToolMacEdition"
DEPLOY_TARGET = "13.0"
TEAM_ID      = "XM9ZKB72R6"    # same team as other RDUtilities projects

# ── Deterministic 24-char uppercase hex ID from a seed string ─────────────────
def uid(seed):
    return hashlib.sha1(seed.encode()).hexdigest()[:24].upper()

# ── Source files relative to project root ─────────────────────────────────────
SWIFT_FILES = [
    "LogSuperToolMacEditionApp.swift",
    "AppState.swift",
    "Models/LogLine.swift",
    "Services/LogFileLoader.swift",
    "ViewModels/LogTabViewModel.swift",
    "Views/ContentView.swift",
    "Views/TabBarView.swift",
    "Views/LogTabView.swift",
    "Views/ToolbarRow.swift",
    "Views/SearchFilterBar.swift",
    "Views/TimelineRow.swift",
    "Views/LogTableView.swift",
    "Views/SidebarView.swift",
    "Views/StatusBarView.swift",
    "Controls/HighlightedText.swift",
    "Controls/FontPanelCoordinator.swift",
]

RESOURCE_FILES = ["Assets.xcassets"]
ENTITLEMENTS_FILE = f"{PROJ_NAME}.entitlements"

# ── Object IDs ────────────────────────────────────────────────────────────────
PROJ_UID             = uid("project_object")
MAIN_GRP_UID         = uid("main_group")
PRODUCTS_GRP_UID     = uid("products_group")
SRC_GRP_UID          = uid("src_group")
MODELS_GRP_UID       = uid("models_group")
SERVICES_GRP_UID     = uid("services_group")
VIEWMODELS_GRP_UID   = uid("viewmodels_group")
VIEWS_GRP_UID        = uid("views_group")
CONTROLS_GRP_UID     = uid("controls_group")
RESOURCES_GRP_UID    = uid("resources_group")
PRODUCT_REF_UID      = uid("product_ref")
ENTITLEMENTS_REF_UID = uid("entitlements_ref")
TARGET_UID           = uid("native_target")
SOURCES_PHASE_UID    = uid("sources_phase")
RESOURCES_PHASE_UID  = uid("resources_phase")
FRAMEWORKS_PHASE_UID = uid("frameworks_phase")
PROJ_CONFIG_LIST     = uid("proj_config_list")
TARGET_CONFIG_LIST   = uid("target_config_list")
PROJ_DEBUG_UID       = uid("proj_debug_config")
PROJ_RELEASE_UID     = uid("proj_release_config")
TARGET_DEBUG_UID     = uid("target_debug_config")
TARGET_RELEASE_UID   = uid("target_release_config")

file_ref_uids   = {f: uid(f"ref_{f}") for f in SWIFT_FILES + RESOURCE_FILES}
build_file_uids = {f: uid(f"bf_{f}")  for f in SWIFT_FILES}
res_build_uids  = {f: uid(f"res_bf_{f}") for f in RESOURCE_FILES}

# ── Helpers ───────────────────────────────────────────────────────────────────
def files_in(folder):
    return [f for f in SWIFT_FILES if os.path.dirname(f) == folder]

def indent(n, text):
    return "\t" * n + text

def group_block(uid_val, name, path, children_uids, source_tree="<group>"):
    lines = [f"\t\t{uid_val} = {{"]
    lines.append(f"\t\t\tisa = PBXGroup;")
    lines.append(f"\t\t\tchildren = (")
    for c in children_uids:
        lines.append(f"\t\t\t\t{c},")
    lines.append(f"\t\t\t);")
    if name:
        lines.append(f"\t\t\tname = {name};")
    if path:
        lines.append(f"\t\t\tpath = {path};")
    lines.append(f"\t\t\tsourceTree = \"{source_tree}\";")
    lines.append(f"\t\t}};")
    return "\n".join(lines)

# ── Project file generator ────────────────────────────────────────────────────
def generate():
    L = []
    def a(s=""): L.append(s)

    a("// !$*UTF8*$!")
    a("{")
    a("\tarchiveVersion = 1;")
    a("\tclasses = {")
    a("\t};")
    a("\tobjectVersion = 77;")
    a("\tobjects = {")
    a()

    # ── PBXBuildFile ──────────────────────────────────────────────────────────
    a("/* Begin PBXBuildFile section */")
    for f in SWIFT_FILES:
        name = os.path.basename(f)
        a(f"\t\t{build_file_uids[f]} /* {name} in Sources */ = "
          f"{{isa = PBXBuildFile; fileRef = {file_ref_uids[f]} /* {name} */; }};")
    for f in RESOURCE_FILES:
        name = os.path.basename(f)
        a(f"\t\t{res_build_uids[f]} /* {name} in Resources */ = "
          f"{{isa = PBXBuildFile; fileRef = {file_ref_uids[f]} /* {name} */; }};")
    a("/* End PBXBuildFile section */")
    a()

    # ── PBXFileReference ──────────────────────────────────────────────────────
    a("/* Begin PBXFileReference section */")
    # Product
    a(f"\t\t{PRODUCT_REF_UID} /* {PROJ_NAME}.app */ = "
      f"{{isa = PBXFileReference; explicitFileType = wrapper.application; "
      f"includeInIndex = 0; path = \"{PROJ_NAME}.app\"; sourceTree = BUILT_PRODUCTS_DIR; }};")
    # Entitlements
    a(f"\t\t{ENTITLEMENTS_REF_UID} /* {ENTITLEMENTS_FILE} */ = "
      f"{{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; "
      f"path = \"{ENTITLEMENTS_FILE}\"; sourceTree = \"<group>\"; }};")
    # Swift sources
    for f in SWIFT_FILES:
        name = os.path.basename(f)
        a(f"\t\t{file_ref_uids[f]} /* {name} */ = "
          f"{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
          f"path = {name}; sourceTree = \"<group>\"; }};")
    # Resources
    for f in RESOURCE_FILES:
        name = os.path.basename(f)
        a(f"\t\t{file_ref_uids[f]} /* {name} */ = "
          f"{{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; "
          f"path = {name}; sourceTree = \"<group>\"; }};")
    a("/* End PBXFileReference section */")
    a()

    # ── PBXFrameworksBuildPhase ───────────────────────────────────────────────
    a("/* Begin PBXFrameworksBuildPhase section */")
    a(f"\t\t{FRAMEWORKS_PHASE_UID} /* Frameworks */ = {{")
    a(f"\t\t\tisa = PBXFrameworksBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a("/* End PBXFrameworksBuildPhase section */")
    a()

    # ── PBXGroup ──────────────────────────────────────────────────────────────
    a("/* Begin PBXGroup section */")
    # Main group
    main_children = [SRC_GRP_UID, MODELS_GRP_UID, SERVICES_GRP_UID,
                     VIEWMODELS_GRP_UID, VIEWS_GRP_UID, CONTROLS_GRP_UID,
                     RESOURCES_GRP_UID, PRODUCTS_GRP_UID]
    a(group_block(MAIN_GRP_UID, None, None, main_children))
    # Products
    a(group_block(PRODUCTS_GRP_UID, "Products", None, [PRODUCT_REF_UID]))
    # Top-level sources
    src_children = [file_ref_uids[f] for f in files_in("")] + [ENTITLEMENTS_REF_UID]
    a(group_block(SRC_GRP_UID, PROJ_NAME, None, src_children))
    # Resources
    a(group_block(RESOURCES_GRP_UID, "Resources", None,
                  [file_ref_uids[f] for f in RESOURCE_FILES]))
    # Sub-folders
    for g_uid, g_name, g_path, g_files in [
        (MODELS_GRP_UID,      "Models",     "Models",     files_in("Models")),
        (SERVICES_GRP_UID,    "Services",   "Services",   files_in("Services")),
        (VIEWMODELS_GRP_UID,  "ViewModels", "ViewModels", files_in("ViewModels")),
        (VIEWS_GRP_UID,       "Views",      "Views",      files_in("Views")),
        (CONTROLS_GRP_UID,    "Controls",   "Controls",   files_in("Controls")),
    ]:
        a(group_block(g_uid, g_name, g_path, [file_ref_uids[f] for f in g_files]))
    a("/* End PBXGroup section */")
    a()

    # ── PBXNativeTarget ───────────────────────────────────────────────────────
    a("/* Begin PBXNativeTarget section */")
    a(f"\t\t{TARGET_UID} /* {PROJ_NAME} */ = {{")
    a(f"\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {TARGET_CONFIG_LIST} /* Build configuration list for PBXNativeTarget \"{PROJ_NAME}\" */;")
    a(f"\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{SOURCES_PHASE_UID} /* Sources */,")
    a(f"\t\t\t\t{FRAMEWORKS_PHASE_UID} /* Frameworks */,")
    a(f"\t\t\t\t{RESOURCES_PHASE_UID} /* Resources */,")
    a(f"\t\t\t);")
    a(f"\t\t\tbuildRules = (")
    a(f"\t\t\t);")
    a(f"\t\t\tdependencies = (")
    a(f"\t\t\t);")
    a(f"\t\t\tname = {PROJ_NAME};")
    a(f"\t\t\tproductName = {PROJ_NAME};")
    a(f"\t\t\tproductReference = {PRODUCT_REF_UID} /* {PROJ_NAME}.app */;")
    a(f"\t\t\tproductType = \"com.apple.product-type.application\";")
    a(f"\t\t}};")
    a("/* End PBXNativeTarget section */")
    a()

    # ── PBXProject ────────────────────────────────────────────────────────────
    a("/* Begin PBXProject section */")
    a(f"\t\t{PROJ_UID} /* Project object */ = {{")
    a(f"\t\t\tisa = PBXProject;")
    a(f"\t\t\tattributes = {{")
    a(f"\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    a(f"\t\t\t\tLastSwiftUpdateCheck = 1630;")
    a(f"\t\t\t\tLastUpgradeCheck = 1630;")
    a(f"\t\t\t\tTargetAttributes = {{")
    a(f"\t\t\t\t\t{TARGET_UID} = {{")
    a(f"\t\t\t\t\t\tCreatedOnToolsVersion = 16.3;")
    a(f"\t\t\t\t\t}};")
    a(f"\t\t\t\t}};")
    a(f"\t\t\t}};")
    a(f"\t\t\tbuildConfigurationList = {PROJ_CONFIG_LIST} /* Build configuration list for PBXProject \"{PROJ_NAME}\" */;")
    a(f"\t\t\tdevelopmentRegion = en;")
    a(f"\t\t\thasScannedForEncodings = 0;")
    a(f"\t\t\tknownRegions = (")
    a(f"\t\t\t\ten,")
    a(f"\t\t\t\tBase,")
    a(f"\t\t\t);")
    a(f"\t\t\tmainGroup = {MAIN_GRP_UID};")
    a(f"\t\t\tminimizedProjectReferenceProxies = 1;")
    a(f"\t\t\tpreferredProjectObjectVersion = 77;")
    a(f"\t\t\tproductRefGroup = {PRODUCTS_GRP_UID} /* Products */;")
    a(f"\t\t\tprojectDirPath = \"\";")
    a(f"\t\t\tprojectRoot = \"\";")
    a(f"\t\t\ttargets = (")
    a(f"\t\t\t\t{TARGET_UID} /* {PROJ_NAME} */,")
    a(f"\t\t\t);")
    a(f"\t\t}};")
    a("/* End PBXProject section */")
    a()

    # ── PBXResourcesBuildPhase ────────────────────────────────────────────────
    a("/* Begin PBXResourcesBuildPhase section */")
    a(f"\t\t{RESOURCES_PHASE_UID} /* Resources */ = {{")
    a(f"\t\t\tisa = PBXResourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    for f in RESOURCE_FILES:
        a(f"\t\t\t\t{res_build_uids[f]} /* {os.path.basename(f)} in Resources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a("/* End PBXResourcesBuildPhase section */")
    a()

    # ── PBXSourcesBuildPhase ──────────────────────────────────────────────────
    a("/* Begin PBXSourcesBuildPhase section */")
    a(f"\t\t{SOURCES_PHASE_UID} /* Sources */ = {{")
    a(f"\t\t\tisa = PBXSourcesBuildPhase;")
    a(f"\t\t\tbuildActionMask = 2147483647;")
    a(f"\t\t\tfiles = (")
    for f in SWIFT_FILES:
        a(f"\t\t\t\t{build_file_uids[f]} /* {os.path.basename(f)} in Sources */,")
    a(f"\t\t\t);")
    a(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a(f"\t\t}};")
    a("/* End PBXSourcesBuildPhase section */")
    a()

    # ── XCBuildConfiguration ──────────────────────────────────────────────────
    a("/* Begin XCBuildConfiguration section */")

    def proj_settings(is_debug):
        s = {}
        s["ALWAYS_SEARCH_USER_PATHS"] = "NO"
        s["ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS"] = "YES"
        s["CLANG_ANALYZER_NONNULL"] = "YES"
        s["CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION"] = "YES_AGGRESSIVE"
        s["CLANG_CXX_LANGUAGE_STANDARD"] = '"gnu++20"'
        s["CLANG_ENABLE_MODULES"] = "YES"
        s["CLANG_ENABLE_OBJC_ARC"] = "YES"
        s["CLANG_ENABLE_OBJC_WEAK"] = "YES"
        s["CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING"] = "YES"
        s["CLANG_WARN_BOOL_CONVERSION"] = "YES"
        s["CLANG_WARN_COMMA"] = "YES"
        s["CLANG_WARN_CONSTANT_CONVERSION"] = "YES"
        s["CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS"] = "YES"
        s["CLANG_WARN_DIRECT_OBJC_ISA_USAGE"] = "YES_ERROR"
        s["CLANG_WARN_DOCUMENTATION_COMMENTS"] = "YES"
        s["CLANG_WARN_EMPTY_BODY"] = "YES"
        s["CLANG_WARN_ENUM_CONVERSION"] = "YES"
        s["CLANG_WARN_INFINITE_RECURSION"] = "YES"
        s["CLANG_WARN_INT_CONVERSION"] = "YES"
        s["CLANG_WARN_NON_LITERAL_NULL_CONVERSION"] = "YES"
        s["CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF"] = "YES"
        s["CLANG_WARN_OBJC_LITERAL_CONVERSION"] = "YES"
        s["CLANG_WARN_OBJC_ROOT_CLASS"] = "YES_ERROR"
        s["CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER"] = "YES"
        s["CLANG_WARN_RANGE_LOOP_ANALYSIS"] = "YES"
        s["CLANG_WARN_STRICT_PROTOTYPES"] = "YES"
        s["CLANG_WARN_SUSPICIOUS_MOVE"] = "YES"
        s["CLANG_WARN_UNGUARDED_AVAILABILITY"] = "YES_AGGRESSIVE"
        s["CLANG_WARN_UNREACHABLE_CODE"] = "YES"
        s["CLANG_WARN__DUPLICATE_METHOD_MATCH"] = "YES"
        s["COPY_PHASE_STRIP"] = "NO"
        s["DEVELOPMENT_TEAM"] = TEAM_ID
        s["ENABLE_STRICT_OBJC_MSGSEND"] = "YES"
        s["ENABLE_USER_SCRIPT_SANDBOXING"] = "YES"
        s["GCC_C_LANGUAGE_STANDARD"] = "gnu17"
        s["GCC_NO_COMMON_BLOCKS"] = "YES"
        s["GCC_WARN_64_TO_32_BIT_CONVERSION"] = "YES"
        s["GCC_WARN_ABOUT_RETURN_TYPE"] = "YES_ERROR"
        s["GCC_WARN_UNDECLARED_SELECTOR"] = "YES"
        s["GCC_WARN_UNINITIALIZED_AUTOS"] = "YES_AGGRESSIVE"
        s["GCC_WARN_UNUSED_FUNCTION"] = "YES"
        s["GCC_WARN_UNUSED_VARIABLE"] = "YES"
        s["LOCALIZATION_PREFERS_STRING_CATALOGS"] = "YES"
        s["MACOSX_DEPLOYMENT_TARGET"] = DEPLOY_TARGET
        s["MTL_FAST_MATH"] = "YES"
        s["SDKROOT"] = "macosx"
        if is_debug:
            s["DEBUG_INFORMATION_FORMAT"] = "dwarf"
            s["ENABLE_TESTABILITY"] = "YES"
            s["GCC_DYNAMIC_NO_PIC"] = "NO"
            s["GCC_OPTIMIZATION_LEVEL"] = "0"
            s['GCC_PREPROCESSOR_DEFINITIONS'] = '(\n\t\t\t\t\t"DEBUG=1",\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t)'
            s["MTL_ENABLE_DEBUG_INFO"] = "INCLUDE_SOURCE"
            s["ONLY_ACTIVE_ARCH"] = "YES"
            s["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = '"DEBUG $(inherited)"'
            s["SWIFT_OPTIMIZATION_LEVEL"] = '"-Onone"'
        else:
            s["DEBUG_INFORMATION_FORMAT"] = '"dwarf-with-dsym"'
            s["ENABLE_NS_ASSERTIONS"] = "NO"
            s["MTL_ENABLE_DEBUG_INFO"] = "NO"
            s["SWIFT_COMPILATION_MODE"] = "wholemodule"
        return s

    def target_settings():
        return {
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
            "ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS": "YES",
            "CODE_SIGN_ENTITLEMENTS": f'"{ENTITLEMENTS_FILE}"',
            "CODE_SIGN_IDENTITY": '"-"',
            "CODE_SIGN_STYLE": "Automatic",
            "COMBINE_HIDPI_IMAGES": "YES",
            "CURRENT_PROJECT_VERSION": "1",
            "DEVELOPMENT_TEAM": TEAM_ID,
            "ENABLE_HARDENED_RUNTIME": "YES",
            "GENERATE_INFOPLIST_FILE": "YES",
            "INFOPLIST_KEY_CFBundleDisplayName": '"LogSuperTool"',
            "INFOPLIST_KEY_LSApplicationCategoryType": '"public.app-category.developer-tools"',
            "INFOPLIST_KEY_NSHumanReadableCopyright": '"Copyright 2026 RDUtilities. MIT License."',
            "INFOPLIST_KEY_NSPrincipalClass": "NSApplication",
            "MACOSX_DEPLOYMENT_TARGET": DEPLOY_TARGET,
            "MARKETING_VERSION": "1.0",
            "PRODUCT_BUNDLE_IDENTIFIER": f'"{BUNDLE_ID}"',
            "PRODUCT_NAME": '"$(TARGET_NAME)"',
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "SWIFT_VERSION": "5.0",
        }

    def write_config(config_uid, name, settings):
        a(f"\t\t{config_uid} /* {name} */ = {{")
        a(f"\t\t\tisa = XCBuildConfiguration;")
        a(f"\t\t\tbuildSettings = {{")
        for k, v in settings.items():
            a(f"\t\t\t\t{k} = {v};")
        a(f"\t\t\t}};")
        a(f"\t\t\tname = {name};")
        a(f"\t\t}};")

    write_config(PROJ_DEBUG_UID,    "Debug",   proj_settings(True))
    write_config(PROJ_RELEASE_UID,  "Release", proj_settings(False))
    ts = target_settings()
    write_config(TARGET_DEBUG_UID,   "Debug",  ts)
    write_config(TARGET_RELEASE_UID, "Release", ts)
    a("/* End XCBuildConfiguration section */")
    a()

    # ── XCConfigurationList ───────────────────────────────────────────────────
    a("/* Begin XCConfigurationList section */")
    a(f"\t\t{PROJ_CONFIG_LIST} /* Build configuration list for PBXProject \"{PROJ_NAME}\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{PROJ_DEBUG_UID} /* Debug */,")
    a(f"\t\t\t\t{PROJ_RELEASE_UID} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a(f"\t\t{TARGET_CONFIG_LIST} /* Build configuration list for PBXNativeTarget \"{PROJ_NAME}\" */ = {{")
    a(f"\t\t\tisa = XCConfigurationList;")
    a(f"\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{TARGET_DEBUG_UID} /* Debug */,")
    a(f"\t\t\t\t{TARGET_RELEASE_UID} /* Release */,")
    a(f"\t\t\t);")
    a(f"\t\t\tdefaultConfigurationIsVisible = 0;")
    a(f"\t\t\tdefaultConfigurationName = Release;")
    a(f"\t\t}};")
    a("/* End XCConfigurationList section */")
    a()

    a("\t};")
    a(f"\trootObject = {PROJ_UID} /* Project object */;")
    a("}")
    return "\n".join(L)

# ── Write helpers ─────────────────────────────────────────────────────────────
def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)
    print(f"  wrote {os.path.relpath(path, ROOT)}")

def main():
    print(f"Generating Xcode project: {ROOT}")

    xcproj = os.path.join(ROOT, f"{PROJ_NAME}.xcodeproj")
    write(os.path.join(xcproj, "project.pbxproj"), generate())

    # xcworkspace stub (required by xcodebuild)
    ws = os.path.join(xcproj, "project.xcworkspace")
    write(os.path.join(ws, "contents.xcworkspacedata"),
          '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<Workspace version = "1.0">\n'
          '   <FileRef location = "self:">\n'
          '   </FileRef>\n'
          '</Workspace>\n')

    # Assets.xcassets
    assets = os.path.join(ROOT, "Assets.xcassets")
    appicon = os.path.join(assets, "AppIcon.appiconset")
    os.makedirs(appicon, exist_ok=True)
    icon_contents = {
        "images": [{"idiom": "mac", "scale": f"{s}x", "size": f"{sz}x{sz}"}
                   for sz in [16,32,128,256,512] for s in [1,2]],
        "info": {"author": "xcode", "version": 1}
    }
    write(os.path.join(appicon, "Contents.json"), json.dumps(icon_contents, indent=2))
    write(os.path.join(assets,  "Contents.json"),
          json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))

    # AccentColor
    accent = os.path.join(assets, "AccentColor.colorset")
    os.makedirs(accent, exist_ok=True)
    write(os.path.join(accent, "Contents.json"),
          json.dumps({"colors": [{"idiom": "universal"}],
                      "info": {"author": "xcode", "version": 1}}, indent=2))

    # Entitlements
    write(os.path.join(ROOT, ENTITLEMENTS_FILE),
          '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
          '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
          '<plist version="1.0">\n<dict>\n'
          '    <key>com.apple.security.app-sandbox</key>\n    <true/>\n'
          '    <key>com.apple.security.files.user-selected.read-only</key>\n    <true/>\n'
          '</dict>\n</plist>\n')

    print(f"\nDone! To open:\n"
          f"  open -a /Volumes/MacMiniStorage/Xcode.app "
          f'"{os.path.join(ROOT, PROJ_NAME + ".xcodeproj")}"')

if __name__ == "__main__":
    main()
